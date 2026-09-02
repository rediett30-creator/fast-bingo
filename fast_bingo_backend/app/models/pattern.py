from __future__ import annotations
from typing import TYPE_CHECKING
from sqlalchemy import JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base

if TYPE_CHECKING:
    from app.models.game import Game

class Pattern(Base):
    __tablename__ = "patterns"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(unique=True)
    description: Mapped[str] = mapped_column()
    covered_cells: Mapped[list[int]] = mapped_column(JSON)

    games: Mapped[list["Game"]] = relationship(back_populates="pattern")