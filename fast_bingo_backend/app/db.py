from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.ext.asyncio import async_sessionmaker
from app.config import Settings

engine =  create_async_engine(Settings().database_url)

SessionLocal = async_sessionmaker(bind=engine,expire_on_commit=False)

async def get_db():
    async with SessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback() 
            raise
        finally:
            await session.close()