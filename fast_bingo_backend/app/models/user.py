from __future__ import annotations
from typing import TYPE_CHECKING, Optional
from sqlalchemy import BigInteger, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base
from app.models.enums import UserRole
from sqlalchemy.types import Enum as SQLEnum
if TYPE_CHECKING:
    from app.models.game_card import GameCard

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    telegram_id: Mapped[int] = mapped_column(BigInteger, unique=True, index=True)
    first_name: Mapped[str] = mapped_column()
    username: Mapped[Optional[str]] = mapped_column()
    role: Mapped[UserRole] = mapped_column(
        SQLEnum(UserRole, values_callable=lambda obj: [e.value for e in obj]),
        default=UserRole.USER
    )

    card_purchases: Mapped[list["GameCard"]] = relationship(back_populates="user")