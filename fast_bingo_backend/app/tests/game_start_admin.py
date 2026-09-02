"""
authenticates as an admin telegram_id, connects to
the game's WebSocket, and sends start_game. T
"""
import argparse
import asyncio
import hashlib
import hmac
import json
import time
import urllib.parse
from datetime import datetime

import httpx
import websockets

from app.config import Settings


settings = Settings()

DEFAULT_BASE_URL = "http://127.0.0.1:8000"  
DEFAULT_ADMIN_TELEGRAM_ID = 900_000_001
DEFAULT_COUNTDOWN_SECONDS = 30



def fake_init_data(telegram_id: int, first_name: str, username: str) -> str:
    user = {"id": telegram_id, "first_name": first_name, "username": username}
    fields = {"user": json.dumps(user), "auth_date": str(int(time.time()))}
    data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(fields.items()))
    secret_key = hmac.new(b"WebAppData", settings.bot_token.encode(), hashlib.sha256).digest()
    fields["hash"] = hmac.new(secret_key, data_check_string.encode(), hashlib.sha256).hexdigest()
    return urllib.parse.urlencode(fields)


async def _login_as_admin(client: httpx.AsyncClient, telegram_id: int) -> str:
    init_data = fake_init_data(telegram_id, "CLI Admin", "cli_admin")
    resp = await client.post("/auth/telegram", json={"init_data": init_data})
    resp.raise_for_status()
    return resp.json()["access_token"]


async def _get_target_game_id(client: httpx.AsyncClient, token: str, explicit_id: int | None) -> int:
    if explicit_id is not None:
        return explicit_id

    resp = await client.get("/games/current", headers={"Authorization": f"Bearer {token}"})
    if resp.status_code == 404:
        raise SystemExit(
            "No pending/active game found via GET /games/current. "
            "Insert one first, or pass --game-id explicitly."
        )
    resp.raise_for_status()
    game = resp.json()
    print(f"Auto-detected current game: id={game['id']} status={game['status']}")
    return game["id"]


def _log(message: dict) -> None:
    ts = datetime.now().strftime("%H:%M:%S")
    msg_type = message.get("type", "unknown")

    if msg_type == "number_called":
        print(f"[{ts}] 🎱 number called: {message['value']} (call #{message['call_index']})")
    elif msg_type == "game_starting":
        print(f"[{ts}] ⏳ countdown started: {message['starts_in_seconds']}s")
    elif msg_type == "game_started":
        print(f"[{ts}] ▶️  game started -- number calling is now live")
    elif msg_type == "game_finished":
        winner = message.get("winner_name", "unknown")
        print(f"[{ts}] 🏆 GAME FINISHED -- winner: {winner} (card {message['winning_card_id']})")
    elif msg_type == "pool_exhausted":
        print(f"[{ts}] ⌛ all numbers called, no winner")
    elif msg_type == "sync":
        print(f"[{ts}] 🔄 sync: status={message['status']} called_so_far={message['called_numbers']}")
    elif msg_type == "error":
        print(f"[{ts}] ❌ error: {message['detail']}")
    else:
        print(f"[{ts}] {message}")


async def main(args: argparse.Namespace) -> None:
    async with httpx.AsyncClient(base_url=args.base_url) as client:
        token = await _login_as_admin(client, args.admin_telegram_id)
        print(f"authenticated as telegram_id={args.admin_telegram_id}")

        game_id = await _get_target_game_id(client, token, args.game_id)

    ws_base = args.base_url.replace("http", "ws")
    ws_url = f"{ws_base}/ws/games/{game_id}?token={token}"

    async with websockets.connect(ws_url) as ws:
        sync_msg = json.loads(await ws.recv())
        _log(sync_msg)

        if sync_msg.get("status") != "pending":
            print(f"Game is already '{sync_msg.get('status')}' -- not sending start_game.")
        else:
            await ws.send(json.dumps({
                "type": "start_game",
                "countdown_seconds": args.countdown,
            }))
            print(f"sent start_game (countdown={args.countdown}s) -- listening for broadcasts, Ctrl+C to stop")

        try:
            while True:
                message = json.loads(await ws.recv())
                _log(message)
                if message.get("type") in ("game_finished", "pool_exhausted"):
                    break
        except KeyboardInterrupt:
            print("\nstopped listening (game keeps running server-side)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--game-id", type=int, default=None, help="omit to auto-detect via GET /games/current")
    parser.add_argument("--countdown", type=float, default=DEFAULT_COUNTDOWN_SECONDS)
    parser.add_argument("--admin-telegram-id", type=int, default=DEFAULT_ADMIN_TELEGRAM_ID)
    asyncio.run(main(parser.parse_args()))