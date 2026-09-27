from typing import AsyncGenerator
import os
import ssl

from sqlalchemy.engine import URL, make_url
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine


# Use KABADIWALA_DATABASE_URL/DATABASE_URL for hosted databases. The component
# variables remain available for the existing local MySQL setup.
database_url = os.getenv("KABADIWALA_DATABASE_URL") or os.getenv("DATABASE_URL")
connect_args = {}

if database_url:
    parsed_url = make_url(database_url)
    if parsed_url.drivername in {"postgres", "postgresql"}:
        # Accept provider PostgreSQL URIs while using the async SQLAlchemy driver.
        query = dict(parsed_url.query)
        sslmode = query.pop("sslmode", None)
        if parsed_url.drivername == "postgres":
            parsed_url = parsed_url.set(drivername="postgresql")
        database_url = parsed_url.set(
            drivername="postgresql+asyncpg", query=query
        )
        if sslmode:
            connect_args["ssl"] = "require" if sslmode == "require" else sslmode
    elif parsed_url.drivername == "mysql":
        # Managed MySQL providers commonly provide mysql:// URIs. This app uses
        # aiomysql; translate provider SSL options into its SSLContext argument.
        query = dict(parsed_url.query)
        sslmode = query.pop("ssl-mode", query.pop("sslmode", None))
        database_url = parsed_url.set(
            drivername="mysql+aiomysql", query=query
        )
        ca_pem = os.getenv("KABADIWALA_DB_SSL_CA")
        if sslmode or ca_pem:
            connect_args["ssl"] = ssl.create_default_context(
                cadata=ca_pem if ca_pem else None
            )
else:
    db_password = os.getenv("KABADIWALA_DB_PASSWORD")
    if not db_password:
        raise RuntimeError(
            "Database credentials are not configured. Set KABADIWALA_DATABASE_URL "
            "or KABADIWALA_DB_PASSWORD (and optionally KABADIWALA_DB_USER, "
            "KABADIWALA_DB_HOST, KABADIWALA_DB_PORT, KABADIWALA_DB_NAME)."
        )
    database_url = URL.create(
        "mysql+aiomysql",
        username=os.getenv("KABADIWALA_DB_USER", "root"),
        password=db_password,
        host=os.getenv("KABADIWALA_DB_HOST", "localhost"),
        port=int(os.getenv("KABADIWALA_DB_PORT", "3306")),
        database=os.getenv("KABADIWALA_DB_NAME", "kabadiwala_db"),
    )

engine_args = {"echo": True, "pool_size": 5, "max_overflow": 10}
if connect_args:
    engine_args["connect_args"] = connect_args

engine = create_async_engine(database_url, **engine_args)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
