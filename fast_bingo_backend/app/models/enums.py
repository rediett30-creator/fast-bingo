# app/models/enums.py
import enum

class UserRole(str, enum.Enum):
    USER = "user"
    ADMIN = "admin"

class GameStatus(str, enum.Enum):
    PENDING = "pending"
    ACTIVE = "active"
    FINISHED = "finished"