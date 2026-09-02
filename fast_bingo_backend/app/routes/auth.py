import json
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.db import get_db
from app.models.user import User
from app.models.enums import UserRole
from app.telegram import validate_init_data, InitDataValidationError
from app.security import create_access_token
from app.config import Settings

settings = Settings()

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/telegram")
async def telegram_login(payload: dict, db: AsyncSession = Depends(get_db)):
    try:
        parsed = validate_init_data(payload["init_data"], settings.bot_token)
    except InitDataValidationError as e:
        raise HTTPException(status_code=401, detail=str(e))

    tg_user = json.loads(parsed["user"])

    try:
        telegram_id = int(tg_user["id"])
    except (ValueError, TypeError, KeyError):
        raise HTTPException(
            status_code=400, 
            detail="Invalid Telegram user ID. It must be a numeric value."
        )

    result = await db.execute(select(User).where(User.telegram_id == telegram_id))
    user = result.scalar_one_or_none()

    if user is None:
        user = User(
            telegram_id=telegram_id, 
            first_name=tg_user["first_name"],
            username=tg_user.get("username"),
            role=UserRole.USER,
        )
        db.add(user)
    else:
        user.first_name = tg_user["first_name"]
        user.username = tg_user.get("username")

    await db.commit()
    await db.refresh(user)

    return {"access_token": create_access_token(user.id, user.role), "token_type": "bearer"}