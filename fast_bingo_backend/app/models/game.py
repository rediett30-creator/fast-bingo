from __future__ import annotations
from datetime import datetime
from typing import TYPE_CHECKING, Optional
from sqlalchemy import ForeignKey, Enum as SAEnum, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base
from app.models.enums import GameStatus

if TYPE_CHECKING:
    from app.models.pattern import Pattern
    from app.models.game_card import GameCard
    from app.models.user import User

class Game(Base):
    __tablename__ = "games"

    id: Mapped[int] = mapped_column(primary_key=True)
    status: Mapped[GameStatus] = mapped_column(SAEnum(GameStatus), default=GameStatus.PENDING)
    card_price: Mapped[int] = mapped_column()
    total_award: Mapped[int] = mapped_column()
    pattern_id: Mapped[int] = mapped_column(ForeignKey("patterns.id"), index=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    started_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    pattern: Mapped["Pattern"] = relationship(back_populates="games")
    cards: Mapped[list["GameCard"]] = relationship(back_populates="game")
    creator: Mapped["User"] = relationship()