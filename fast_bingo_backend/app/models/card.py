from __future__ import annotations
from typing import TYPE_CHECKING, Optional
from sqlalchemy import JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base

if TYPE_CHECKING:
    from app.models.game_card import GameCard

class Card(Base):
    __tablename__ = "cards"

    id: Mapped[int] = mapped_column(primary_key=True)
    grid: Mapped[list[Optional[int]]] = mapped_column(JSON)   

    purchases: Mapped[list["GameCard"]] = relationship(back_populates="card")