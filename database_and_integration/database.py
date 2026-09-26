from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.engine import URL
from typing import AsyncGenerator
import os

# Keep credentials out of source control. Set KABADIWALA_DATABASE_URL in the
# environment, for example:
# mysql+aiomysql://user:password@localhost:3306/kabadiwala_db
DATABASE_URL = os.getenv("KABADIWALA_DATABASE_URL")
if not DATABASE_URL:
    # Component variables avoid URL-encoding issues with special characters
    # in the password.
    db_password = os.getenv("KABADIWALA_DB_PASSWORD")
    if not db_password:
        raise RuntimeError(
            "Database credentials are not configured. Set KABADIWALA_DATABASE_URL "
            "or KABADIWALA_DB_PASSWORD (and optionally KABADIWALA_DB_USER, "
            "KABADIWALA_DB_HOST, KABADIWALA_DB_PORT, KABADIWALA_DB_NAME)."
        )
    DATABASE_URL = URL.create(
        "mysql+aiomysql",
        username=os.getenv("KABADIWALA_DB_USER", "root"),
        password=db_password,
        host=os.getenv("KABADIWALA_DB_HOST", "localhost"),
        port=int(os.getenv("KABADIWALA_DB_PORT", "3306")),
        database=os.getenv("KABADIWALA_DB_NAME", "kabadiwala_db"),
    )

engine = create_async_engine(
    DATABASE_URL,
    echo=True,
    pool_size=5,
    max_overflow=10
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False
)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
