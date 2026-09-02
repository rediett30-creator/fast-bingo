from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.db import get_db
from app.deps import require_admin
from app.models.user import User
from app.models.game import Game
from app.models.game_card import GameCard
from app.models.pattern import Pattern
from app.models.enums import GameStatus
from app.schemas.game import GameCreate, GameRead
from sqlalchemy.orm import selectinload
from app.schemas.game import GameWithPattern
from app.deps import get_current_user

router = APIRouter(prefix="/games", tags=["games"])


@router.post("", response_model=GameRead, status_code=201)
async def create_game(
    payload: GameCreate,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    pattern = await db.get(Pattern, payload.pattern_id)
    if pattern is None:
        raise HTTPException(status_code=404, detail="Pattern not found")

    game = Game(
        card_price=payload.card_price,
        total_award=payload.total_award,
        pattern_id=payload.pattern_id,
        created_by=admin.id,
        status=GameStatus.PENDING,
    )
    existing = await db.scalar(
    select(Game.id).where(Game.status.in_([GameStatus.PENDING, GameStatus.ACTIVE])).limit(1)
    )
    if existing is not None:
        raise HTTPException(status_code=409, detail="A game is already pending or active")
    db.add(game)
    await db.commit()
    await db.refresh(game)
    return game


@router.get("/current", response_model=GameWithPattern)
async def get_current_game(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Game)
        .options(selectinload(Game.pattern))
        .where(Game.status.in_([GameStatus.PENDING, GameStatus.ACTIVE]))
        .order_by(Game.created_at.desc())
        .limit(1)
    )
    game = result.scalar_one_or_none()
    if game is None:
        raise HTTPException(status_code=404, detail="No game is currently open")
    return game

@router.delete("/{game_id}", status_code=204)
async def delete_game(
    game_id: int,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    game = await db.get(Game, game_id)
    if game is None:
        raise HTTPException(status_code=404, detail="Game not found")

    if game.status != GameStatus.PENDING:
        raise HTTPException(
            status_code=400,
            detail="Only pending games can be deleted; started/finished games are kept for audit",
        )

    purchased_count = await db.scalar(
        select(func.count()).select_from(GameCard).where(GameCard.game_id == game_id)
    )
    if purchased_count:
        raise HTTPException(
            status_code=409,
            detail="Cannot delete a game that already has purchased cards",
        )

    await db.delete(game)
    await db.commit()