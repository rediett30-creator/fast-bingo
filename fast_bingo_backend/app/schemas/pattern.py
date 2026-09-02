from pydantic import BaseModel, ConfigDict

class PatternRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    covered_cells: list[int]