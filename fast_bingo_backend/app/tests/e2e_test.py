import asyncio
import hashlib
import hmac
import json
import random
import time
import urllib.parse

import httpx
import websockets
from sqlalchemy import select

from app.config import Settings
from app.db import SessionLocal  
from app.models import User, Card, Pattern, Game, GameCard
from app.models.enums import UserRole

BASE_URL = "http://127.0.0.1:8000"  

ADMIN_TELEGRAM_ID = 900_000_001
USER_TELEGRAM_ID = 900_000_002
SPECTATOR_TELEGRAM_ID = 900_000_003
settings = Settings()  

def fake_init_data(telegram_id: int, first_name: str, username: str) -> str:
    user = {"id": telegram_id, "first_name": first_name, "username": username}
    fields = {"user": json.dumps(user), "auth_date": str(int(time.time()))}
    data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(fields.items()))
    secret_key = hmac.new(b"WebAppData", settings.bot_token.encode(), hashlib.sha256).digest()
    fields["hash"] = hmac.new(secret_key, data_check_string.encode(), hashlib.sha256).hexdigest()
    return urllib.parse.urlencode(fields)


async def _login(client: httpx.AsyncClient, telegram_id: int, first_name: str, username: str) -> str:
    init_data = fake_init_data(telegram_id, first_name, username)
    resp = await client.post("/auth/telegram", json={"init_data": init_data})
    resp.raise_for_status()
    return resp.json()["access_token"]


def _bearer(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def generate_card_grid() -> list:
    ranges = [(1, 15), (16, 30), (31, 45), (46, 60), (61, 75)]
    columns = [random.sample(range(lo, hi + 1), 5) for lo, hi in ranges]
    grid = [None] * 25
    for row in range(5):
        for col in range(5):
            grid[row * 5 + col] = columns[col][row]
    grid[12] = None  # free space
    return grid


async def _ensure_admin(db, telegram_id: int) -> User:
    result = await db.execute(select(User).where(User.telegram_id == telegram_id))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(telegram_id=telegram_id, first_name="QA Admin", username="qa_admin", role=UserRole.ADMIN)
        db.add(user)
        await db.commit()
    elif user.role != UserRole.ADMIN:
        user.role = UserRole.ADMIN
        await db.commit()
    return user


async def _ensure_test_pattern(db) -> Pattern:
    result = await db.execute(select(Pattern).where(Pattern.name == "QA Smoke Test"))
    pattern = result.scalar_one_or_none()
    if pattern is None:
        pattern = Pattern(
            name="QA Smoke Test",
            description="Automated-test-only pattern, fast to complete. Don't offer this in the real gallery.",
            covered_cells=[0, 1],
        )
        db.add(pattern)
        await db.commit()
        await db.refresh(pattern)
    return pattern


async def _create_test_cards(db) -> tuple[Card, Card]:
    card_a = Card(grid=generate_card_grid())
    card_b = Card(grid=generate_card_grid())
    db.add_all([card_a, card_b])
    await db.commit()
    await db.refresh(card_a)
    await db.refresh(card_b)
    return card_a, card_b

async def recv_json(ws) -> dict:
    return json.loads(await ws.recv())


async def wait_for_type(ws, type_: str) -> dict:
    while True:
        msg = await recv_json(ws)
        if msg["type"] == type_:
            return msg


def _pattern_satisfied(grid: list, called: list[int], covered_cells: list[int]) -> bool:
    """Mirrors the server's own check in validate_bingo -- the test predicts
    server behavior using the exact same rule, deliberately."""
    called_set = set(called)
    return all(grid[i] is None or grid[i] in called_set for i in covered_cells)


async def run_user_flow(ws, card_a: dict, card_b: dict, covered_cells: list[int]) -> dict:
    results = {"lost": False, "late": False, "won": False}
    called: list[int] = []

    await wait_for_type(ws, "game_starting")
    await wait_for_type(ws, "game_started")
    print("  [user] game started, listening for calls...")

    await ws.send(json.dumps({"type": "bingo", "card_id": card_a["id"]}))
    resp = await recv_json(ws)
    assert resp["outcome"] == "lost", f"expected lost, got {resp}"
    results["lost"] = True
    print("  [user] early claim correctly rejected: LOST")

    card_a_completed_at = None
    card_b_claimed = False

    while not (results["late"] and results["won"]):
        msg = await recv_json(ws)
        if msg["type"] != "number_called":
            continue
        called.append(msg["value"])

        if not results["late"]:
            if card_a_completed_at is None and _pattern_satisfied(card_a["grid"], called, covered_cells):
                card_a_completed_at = len(called)
            elif card_a_completed_at is not None and len(called) == card_a_completed_at + 1:
                await ws.send(json.dumps({"type": "bingo", "card_id": card_a["id"]}))
                resp = await recv_json(ws)
                assert resp["outcome"] == "late", f"expected late, got {resp}"
                results["late"] = True
                print("  [user] stale claim correctly rejected: LATE")

       
        if not card_b_claimed and _pattern_satisfied(card_b["grid"], called, covered_cells):
            await ws.send(json.dumps({"type": "bingo", "card_id": card_b["id"]}))
            card_b_claimed = True

        if card_b_claimed and not results["won"]:
            finish = await recv_json(ws)
            assert finish["type"] == "game_finished", f"expected game_finished, got {finish}"
            assert finish["winning_card_id"] == card_b["id"]
            results["won"] = True
            print("  [user] timely claim correctly accepted: WON")

    return results


async def run_spectator_flow(ws) -> dict:
    result = {"saw_finish": False, "finish_payload": None}
    while not result["saw_finish"]:
        msg = await recv_json(ws)
        if msg["type"] == "game_finished":
            result["saw_finish"] = True
            result["finish_payload"] = msg
    return result


async def main():
    async with SessionLocal() as db:
        pattern = await _ensure_test_pattern(db)
        
        pattern_id = pattern.id
        pattern_cells = pattern.covered_cells

        await _ensure_admin(db, ADMIN_TELEGRAM_ID)

        card_a, card_b = await _create_test_cards(db)
    
        card_a_dict = {"id": card_a.id, "grid": card_a.grid}
        card_b_dict = {"id": card_b.id, "grid": card_b.grid}

    print(f"seeded: pattern={pattern_id} card_a={card_a_dict['id']} card_b={card_b_dict['id']}")

    async with httpx.AsyncClient(base_url=BASE_URL) as client:
        admin_token = await _login(client, ADMIN_TELEGRAM_ID, "QA Admin", "qa_admin")
        user_token = await _login(client, USER_TELEGRAM_ID, "QA Player", "qa_player")
        spectator_token = await _login(client, SPECTATOR_TELEGRAM_ID, "QA Spectator", "qa_spectator")
        print("all three identities authenticated")

        game_resp = await client.post(
            "/games",
            json={"card_price": 10, "total_award": 100, "pattern_id": pattern_id},
            headers=_bearer(admin_token),
        )
        game_resp.raise_for_status()
        game_id = game_resp.json()["id"]
        print(f"created game {game_id}")

        for card in (card_a_dict, card_b_dict):
            r = await client.post(f"/games/{game_id}/cards/{card['id']}", headers=_bearer(user_token))
            r.raise_for_status()
        print("bought both cards")

    ws_base = BASE_URL.replace("http", "ws")
    admin_url = f"{ws_base}/ws/games/{game_id}?token={admin_token}"
    user_url = f"{ws_base}/ws/games/{game_id}?token={user_token}"
    spectator_url = f"{ws_base}/ws/games/{game_id}?token={spectator_token}"

    async with websockets.connect(admin_url) as admin_ws, \
               websockets.connect(user_url) as user_ws, \
               websockets.connect(spectator_url) as spectator_ws:

        await recv_json(admin_ws)  
        await recv_json(user_ws)
        await recv_json(spectator_ws)
        print("all sockets connected and synced")

        user_task = asyncio.create_task(
            run_user_flow(
                user_ws,
                card_a_dict,
                card_b_dict,
                pattern_cells,
            )
        )
        spectator_task = asyncio.create_task(run_spectator_flow(spectator_ws))

        await asyncio.sleep(0.3)  
        await admin_ws.send(json.dumps({"type": "start_game", "countdown_seconds": 10}))
        print("admin started the game (10s countdown)...")

        user_result, spectator_result = await asyncio.wait_for(
            asyncio.gather(user_task, spectator_task), timeout=400
        )

    assert user_result["lost"] and user_result["late"] and user_result["won"]
    assert spectator_result["saw_finish"]
    assert spectator_result["finish_payload"]["winning_card_id"] == card_b_dict["id"]

    print("\nALL CHECKS PASSED")
    print(f"  early claim rejected as LOST         : {user_result['lost']}")
    print(f"  stale claim rejected as LATE         : {user_result['late']}")
    print(f"  timely claim accepted as WON         : {user_result['won']}")
    print(f"  non-participant got the broadcast    : {spectator_result['saw_finish']}")

if __name__ == "__main__":
    asyncio.run(main())