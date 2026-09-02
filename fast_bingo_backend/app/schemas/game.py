from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field
from app.models.enums import GameStatus
from app.schemas.pattern import PatternRead

class GameCreate(BaseModel):
    card_price: int = Field(gt=0)
    total_award: int = Field(gt=0)
    pattern_id: int

class GameRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    status: GameStatus
    card_price: int
    total_award: int
    pattern_id: int
    created_by: int
    started_at: Optional[datetime]
    created_at: datetime

class GameWithPattern(GameRead):
    pattern: PatternRead