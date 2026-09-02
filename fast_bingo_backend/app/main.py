from fastapi import FastAPI
from app.routes import auth, games,cards, patterns, game_card, game_ws
from fastapi.middleware.cors import CORSMiddleware


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(games.router)
app.include_router(cards.router)
app.include_router(patterns.router)
app.include_router(game_card.router)
app.include_router(game_ws.router)

@app.get("/")
async def root():
    return {"message": "Welcome to the Fast Bingo Backend!"}