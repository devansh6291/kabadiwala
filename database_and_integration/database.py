from typing import AsyncGenerator
import base64
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
    elif parsed_url.drivername in {"mysql", "mysql+aiomysql"}:
        # Managed MySQL providers commonly provide mysql:// URIs. This app uses
        # aiomysql; translate provider SSL options into its SSLContext argument.
        query = dict(parsed_url.query)
        ssl_flag = query.pop("ssl", None)
        sslmode = query.pop("ssl-mode", None) or query.pop("sslmode", None)
        database_url = parsed_url.set(
            drivername="mysql+aiomysql", query=query
        )
        ca_pem = os.getenv("KABADIWALA_DB_SSL_CA")
        ssl_setting = (sslmode or ssl_flag or "").lower()
        ssl_enabled = ssl_setting not in {"", "0", "false", "no", "disabled"}
        if ssl_enabled or ca_pem:
            if not ca_pem:
                connect_args["ssl"] = ssl.create_default_context()
            elif os.path.isfile(ca_pem.strip()):
                connect_args["ssl"] = ssl.create_default_context(
                    cafile=ca_pem.strip()
                )
            else:
                ca_pem = ca_pem.strip().replace("\\n", "\n")
                if "-----BEGIN CERTIFICATE-----" not in ca_pem:
                    try:
                        ca_pem = base64.b64decode(ca_pem, validate=True).decode(
                            "utf-8"
                        )
                    except (ValueError, UnicodeDecodeError) as error:
                        raise RuntimeError(
                            "KABADIWALA_DB_SSL_CA must be Aiven CA PEM contents, "
                            "a CA file path available to the service, or base64-encoded PEM."
                        ) from error
                if "-----BEGIN CERTIFICATE-----" not in ca_pem:
                    raise RuntimeError(
                        "KABADIWALA_DB_SSL_CA does not contain a PEM certificate. "
                        "Copy Aiven's CA certificate, including its BEGIN/END lines."
                    )
                connect_args["ssl"] = ssl.create_default_context(cadata=ca_pem)
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
