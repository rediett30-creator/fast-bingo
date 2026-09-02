from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db import get_db
from app.deps import get_current_user
from app.models.user import User
from app.models.game import Game
from app.models.card import Card
from app.models.game_card import GameCard
from app.models.enums import GameStatus
from app.schemas.game_card import GameCardRead


router = APIRouter(prefix="/games/{game_id}/cards", tags=["game-cards"])


@router.post("/{card_id}", response_model=GameCardRead, status_code=201)
async def buy_card(
    game_id: int,
    card_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    game = await db.get(Game, game_id)
    if game is None:
        raise HTTPException(status_code=404, detail="Game not found")
    if game.status != GameStatus.PENDING:
        raise HTTPException(status_code=400, detail="Cards can only be bought before the game starts")

    card = await db.get(Card, card_id)
    if card is None:
        raise HTTPException(status_code=404, detail="Card not found")

    db.add(GameCard(game_id=game_id, card_id=card_id, user_id=user.id))
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="This card was just bought by someone else for this game")

    result = await db.execute(
        select(GameCard)
        .options(selectinload(GameCard.card))
        .where(GameCard.game_id == game_id, GameCard.card_id == card_id, GameCard.user_id == user.id)
    )
    return result.scalar_one()


@router.get("/mine", response_model=list[GameCardRead])
async def my_cards(
    game_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(GameCard)
        .options(selectinload(GameCard.card))
        .where(GameCard.game_id == game_id, GameCard.user_id == user.id)
        .order_by(GameCard.id)
    )
    return result.scalars().all()