<p align="center">
  <img src="screenshots/dashboard.jpg" width="23%" />
  <img src="screenshots/cards.jpg" width="23%" />
  <img src="screenshots/play.jpg" width="23%" />
  <img src="screenshots/win.jpg" width="23%" />
  <img src="screenshots/admin_dashboard.jpg" width="23%" />
</p>

# Fast Bingo

Fast Bingo is a real-time multiplayer bingo game that runs as a Telegram
Mini App. Players buy cards, an admin starts the game, numbers get called
out live over a websocket, and the server is the one deciding who actually
won — not the client. Built the backend with FastAPI and the frontend with
Flutter, both talking to each other over REST and a websocket connection.

I built this mostly to get comfortable with real-time systems — websockets,
race conditions, the kind of problems that don't really show up when you're
building a typical CRUD app.

## How it works

- Logging in happens through Telegram itself, no signup form. The app reads
  the data Telegram hands it when the Mini App opens, the backend checks
  that it's genuinely signed by Telegram, and issues its own session token
  from there.
- An admin creates a game: sets the price per card, the total prize, and
  picks a winning pattern from a small gallery (a straight line, four
  corners, an X shape, and so on).
- Players buy one or more cards before the game starts. Cards aren't
  generated fresh for every game — they come from a shared pool and get
  reused across rounds, similar to how a real bingo hall reuses the same
  numbered cards session after session.
- Once the admin starts the game, there's a short countdown and then the
  server starts calling numbers on its own, broadcasting each one to every
  connected player.
- Tapping "Bingo" sends a claim to the server. It checks whether the
  pattern is actually complete using only numbers that have really been
  called, and whether the claim landed on the exact call that completed
  it — so claiming a few calls late doesn't count, even if the pattern
  happens to still be technically complete.
- Whoever wins first ends the game for everyone. Every connected player
  sees who won and what the winning card looked like, not just the winner.

## Tech stack

**Backend** — FastAPI, PostgreSQL, SQLAlchemy (async), plain FastAPI/Starlette
websockets (no Socket.IO), JWT sessions, deployed on FastAPI Cloud.

**Frontend** — Flutter, built for web and loaded inside Telegram as a Mini
App, deployed on Vercel. Uses `flutter_telegram_miniapp` for the Telegram
side of things, `web_socket_channel` for the live connection, and
`audioplayers` for the number call-outs.

## Project structure

```
fast_bingo_backend/   FastAPI app — REST routes, websocket handler, models
fast_bingo_web/        Flutter frontend
```

## Running it locally

### Backend

```bash
cd fast_bingo_backend
uv sync   # or: pip install -r requirements.txt
```

Create a `.env` file with:

```
DATABASE_URL=postgresql+asyncpg://user:password@host:5432/dbname
SECRET_KEY=replace-with-a-long-random-string
ALGORITHM=HS256
BOT_TOKEN=your-telegram-bot-token
ACCESS_TOKEN_EXPIRE_MINUTES=60
```

`SECRET_KEY` is what signs and verifies session tokens, so generate a real
random one (`openssl rand -hex 32` works fine) rather than typing something
short. `BOT_TOKEN` comes from @BotFather when you register your bot.

Double-check `.env` is actually listed in `.gitignore` before your first
commit — once real values are in here, this file should never end up in
git history, even by accident.

Then run it:

```bash
uv run uvicorn app.main:app --reload
```

The database schema right now is created straight from the SQLAlchemy
models rather than through proper migrations — there's a small reset
script in the repo for wiping and rebuilding it during development. Fine
for now, but this needs Alembic before it's handling anyone's real data
long-term.

### Frontend

Before building, open `lib/config.dart` and point both URLs at your own
backend instead of mine:

```dart
class AppConfig {
  AppConfig._();
  static const String baseUrl = 'https://your-backend-url';
  static const String wsBaseUrl = 'wss://your-backend-url';
}
```

The values currently checked into this repo point at my own hosted
backend. If you skip this step, your build will just talk to my instance
instead of yours.

```bash
cd fast_bingo_web
flutter pub get
flutter build web --release
```

Worth knowing: this only really works properly when it's actually loaded
inside Telegram, since login depends on data that Telegram itself injects
into the page. Opening the built site directly in a normal browser tab
will just show a "please open this inside Telegram" message.

## A few honest limitations

- Only one game can be pending or active at a time — that's a deliberate
  choice to keep everyone drawing from the same shared game rather than
  splitting attention across parallel ones, not a technical limit.
- There's no real payment system yet. Card price and prize amount are just
  numbers shown in the UI right now, not tied to any actual wallet or
  payment flow.
- The list of called numbers and the countdown for a running game live in
  server memory, not the database — a server restart mid-game currently
  loses that game's progress.
- Everything runs as a single backend process. The websocket connections
  and in-memory game state wouldn't be shared correctly across multiple
  server instances without adding something like Redis pub/sub first.

## License

This project is licensed under the MIT License.
