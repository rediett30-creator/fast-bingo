import asyncio
import random
from collections import defaultdict
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, WebSocketException, Depends
from pydantic import BaseModel, Field, ValidationError
from sqlalchemy import update, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db import get_db, SessionLocal 
from app.deps import get_ws_user
from app.models.game import Game
from app.models.game_card import GameCard
from app.models.enums import GameStatus, UserRole
from app.services.bingo_validator import BingoOutcome
from app.services.game_resolution import resolve_bingo_claim

router = APIRouter()

DEFAULT_COUNTDOWN_SECONDS = 30.0
MIN_COUNTDOWN_SECONDS = 10.0
MAX_COUNTDOWN_SECONDS = 120.0


class StartGamePayload(BaseModel):
    countdown_seconds: float = Field(
        default=DEFAULT_COUNTDOWN_SECONDS, ge=MIN_COUNTDOWN_SECONDS, le=MAX_COUNTDOWN_SECONDS
    )

class ConnectionManager:
    def __init__(self):
        self.connections: dict[int, set[WebSocket]] = defaultdict(set)
        self.called_numbers: dict[int, list[int]] = defaultdict(list)
        self._pool: dict[int, list[int]] = {}
        self._calling_tasks: dict[int, asyncio.Task] = {}
        self._countdown_tasks: dict[int, asyncio.Task] = {}
        self._locks: dict[int, asyncio.Lock] = defaultdict(asyncio.Lock)

    def connect(self, game_id: int, websocket: WebSocket) -> None:
        self.connections[game_id].add(websocket)

    def disconnect(self, game_id: int, websocket: WebSocket) -> None:
        self.connections[game_id].discard(websocket)

    async def broadcast(self, game_id: int, message: dict) -> None:
        dead = []
        for ws in self.connections[game_id]:
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.connections[game_id].discard(ws)

    async def start_countdown(self, game_id: int, seconds: float) -> bool:
        """False if a countdown or the calling loop is already running -- a duplicate start_game click is then a safe no-op."""
        async with self._locks[game_id]:
            existing = self._countdown_tasks.get(game_id)
            if existing and not existing.done():
                return False
            calling = self._calling_tasks.get(game_id)
            if calling and not calling.done():
                return False
            self._countdown_tasks[game_id] = asyncio.create_task(self._run_countdown(game_id, seconds))
            return True

    async def _run_countdown(self, game_id: int, seconds: float) -> None:
        try:
            await asyncio.sleep(seconds)
            await _activate_game(game_id)
        except asyncio.CancelledError:
            pass

    async def start_calling(self, game_id: int, interval_seconds: float = 10.0) -> None:
        async with self._locks[game_id]:
            existing = self._calling_tasks.get(game_id)
            if existing and not existing.done():
                return
            pool = list(range(1, 76))
            random.shuffle(pool)
            self._pool[game_id] = pool
            self._calling_tasks[game_id] = asyncio.create_task(self._run_caller(game_id, interval_seconds))

    def stop_calling(self, game_id: int) -> None:
        task = self._calling_tasks.get(game_id)
        if task and not task.done():
            task.cancel()

    async def _run_caller(self, game_id: int, interval_seconds: float) -> None:
        try:
            while self._pool.get(game_id):
                await asyncio.sleep(interval_seconds)
                number = self._pool[game_id].pop()
                self.called_numbers[game_id].append(number)
                await self.broadcast(game_id, {
                    "type": "number_called", "value": number, "call_index": len(self.called_numbers[game_id]),
                })
            await self.broadcast(game_id, {"type": "pool_exhausted"})
        except asyncio.CancelledError:
            pass


manager = ConnectionManager()


async def _get_fresh_game(db: AsyncSession, game_id: int) -> Optional[Game]:
    """Forces a real reload even if this session already cached this row -- see note above on why plain select() isn't safe here."""
    result = await db.execute(
        select(Game)
        .options(selectinload(Game.pattern))
        .where(Game.id == game_id)
        .execution_options(populate_existing=True)
    )
    return result.scalar_one_or_none()


async def _activate_game(game_id: int) -> None:
    """
    Runs from a background task after the countdown ends -- opens its own
    session rather than reusing any connection's, since it executes
    concurrently with whatever that connection's receive loop is doing.
    """
    async with SessionLocal() as db:
        result = await db.execute(
            update(Game)
            .where(Game.id == game_id, Game.status == GameStatus.PENDING)
            .values(status=GameStatus.ACTIVE, started_at=datetime.now(timezone.utc))
        )
        await db.commit()
        if result.rowcount != 1:
            return

    await manager.broadcast(game_id, {"type": "game_started"})
    await manager.start_calling(game_id)



async def _handle_start_game(db: AsyncSession, game_id: int, raw_payload: dict, websocket: WebSocket) -> None:
    try:
        payload = StartGamePayload(**{k: v for k, v in raw_payload.items() if k != "type"})
    except ValidationError:
        await websocket.send_json({
            "type": "error",
            "detail": f"countdown_seconds must be between {MIN_COUNTDOWN_SECONDS} and {MAX_COUNTDOWN_SECONDS}",
        })
        return

    game = await _get_fresh_game(db, game_id)
    if game is None or game.status != GameStatus.PENDING:
        await websocket.send_json({"type": "error", "detail": "Game already started or finished"})
        return

    started = await manager.start_countdown(game_id, payload.countdown_seconds)
    if not started:
        return  

    starts_at = datetime.now(timezone.utc).timestamp() + payload.countdown_seconds
    await manager.broadcast(game_id, {
        "type": "game_starting",
        "starts_in_seconds": payload.countdown_seconds,
        "starts_at": starts_at, 
    })


async def _handle_bingo_claim(db: AsyncSession, game_id: int, user, card_id: int, websocket: WebSocket) -> None:
    game = await _get_fresh_game(db, game_id)
    if game is None:
        await websocket.send_json({"type": "error", "detail": "Game not found"})
        return

    gc_result = await db.execute(
        select(GameCard)
        .options(selectinload(GameCard.card))
        .where(GameCard.game_id == game_id, GameCard.card_id == card_id)
        .execution_options(populate_existing=True)
    )
    game_card = gc_result.scalar_one_or_none()

    if game_card is None or game_card.user_id != user.id:
        await websocket.send_json({"type": "error", "detail": "Not your card"})
        return

    resolution = await resolve_bingo_claim(
        db=db, game=game, game_card=game_card,
        called_numbers=list(manager.called_numbers[game_id]),
        covered_cells=game.pattern.covered_cells,
    )

    if resolution.outcome == BingoOutcome.WON:
        manager.stop_calling(game_id)
        await manager.broadcast(game_id, {
            "type": "game_finished",
            "winner_user_id": user.id,
            "winner_name": user.first_name,
            "winning_card_id": card_id,
            "winning_grid": game_card.card.grid,
        })
    else:
        await websocket.send_json({
            "type": "bingo_result", "outcome": resolution.outcome, "reason": resolution.reason,
        })


@router.websocket("/ws/games/{game_id}")
async def game_ws(websocket: WebSocket, game_id: int, db: AsyncSession = Depends(get_db)):
    await websocket.accept()

    try:
        user = await get_ws_user(websocket, db)
    except WebSocketException:
        await websocket.close(code=1008)
        return

    game = await _get_fresh_game(db, game_id)
    if game is None:
        await websocket.close(code=1008)
        return

    manager.connect(game_id, websocket)

    await websocket.send_json({
        "type": "sync", "status": game.status.value, "called_numbers": manager.called_numbers[game_id],
    })

    try:
        while True:
            try:
                data = await websocket.receive_json()
            except WebSocketDisconnect:
                raise
            except Exception:
                await websocket.send_json({"type": "error", "detail": "Invalid message"})
                continue

            msg_type = data.get("type")

            if msg_type == "start_game":
                if user.role != UserRole.ADMIN:
                    await websocket.send_json({"type": "error", "detail": "Admin only"})
                    continue
                await _handle_start_game(db, game_id, data, websocket)

            elif msg_type == "bingo":
                await _handle_bingo_claim(db, game_id, user, data.get("card_id"), websocket)

            else:
                await websocket.send_json({"type": "error", "detail": f"Unknown message type: {msg_type}"})

    except WebSocketDisconnect:
        manager.disconnect(game_id, websocket)