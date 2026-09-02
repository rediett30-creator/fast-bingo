from __future__ import annotations
from datetime import datetime
from typing import TYPE_CHECKING
from sqlalchemy import ForeignKey, DateTime, func, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base

if TYPE_CHECKING:
    from app.models.game import Game
    from app.models.card import Card
    from app.models.user import User

class GameCard(Base):
    __tablename__ = "game_cards"
    __table_args__ = (
        UniqueConstraint("game_id", "card_id", name="uq_card_once_per_game"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    game_id: Mapped[int] = mapped_column(ForeignKey("games.id"), index=True)
    card_id: Mapped[int] = mapped_column(ForeignKey("cards.id"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    is_winner: Mapped[bool] = mapped_column(default=False)
    purchased_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    game: Mapped["Game"] = relationship(back_populates="cards") 
    card: Mapped["Card"] = relationship(back_populates="purchases")
    user: Mapped["User"] = relationship(back_populates="card_purchases")