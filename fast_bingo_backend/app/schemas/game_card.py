from datetime import datetime
from pydantic import BaseModel, ConfigDict
from app.schemas.card import CardRead

class GameCardRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    game_id: int
    is_winner: bool
    purchased_at: datetime
    card: CardRead   