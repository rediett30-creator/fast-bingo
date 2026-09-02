from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.deps import get_current_user
from app.models.user import User
from app.models.pattern import Pattern
from app.schemas.pattern import PatternRead

router = APIRouter(prefix="/patterns", tags=["patterns"])


@router.get("", response_model=list[PatternRead])
async def list_patterns(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Pattern).order_by(Pattern.id))
    return result.scalars().all()