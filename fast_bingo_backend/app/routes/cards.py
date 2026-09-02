from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.deps import get_current_user
from app.models.user import User
from app.models.card import Card
from app.models.game_card import GameCard
from app.schemas.card import CardRead, PaginatedCards

router = APIRouter(prefix="/cards", tags=["cards"])


@router.get("", response_model=PaginatedCards)
async def list_cards(
    game_id: Optional[int] = Query(
        default=None,
        description="If set, excludes cards already purchased for this game — i.e. what's still buyable",
    ),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Card)
    count_stmt = select(func.count()).select_from(Card)

    if game_id is not None:
        taken = select(GameCard.card_id).where(GameCard.game_id == game_id)
        stmt = stmt.where(Card.id.notin_(taken))
        count_stmt = count_stmt.where(Card.id.notin_(taken))

    total = await db.scalar(count_stmt)
    result = await db.execute(stmt.order_by(Card.id).limit(limit).offset(offset))

    return PaginatedCards(items=result.scalars().all(), total=total, limit=limit, offset=offset)