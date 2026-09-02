from typing import Optional
from pydantic import BaseModel, ConfigDict

class CardRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    grid: list[Optional[int]]

class PaginatedCards(BaseModel):
    items: list[CardRead]
    total: int
    limit: int
    offset: int