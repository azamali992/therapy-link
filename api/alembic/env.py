import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.ext.asyncio import create_async_engine

from alembic import context
from therapylink_api import models  # noqa: F401
from therapylink_api.db import Base, engine_kwargs
from therapylink_api.settings import get_settings

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)
config.set_main_option("sqlalchemy.url", get_settings().database_url)
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(url=config.get_main_option("sqlalchemy.url"), target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def _run(connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata, render_as_batch=True)
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    url = config.get_main_option("sqlalchemy.url")
    # Same pooler handling as the app, minus the pool sizes that NullPool doesn't take. Not
    # db.make_engine: its sqlite foreign-key pragma would make batch migrations, which drop and
    # recreate a table, cascade-delete every row that points at it.
    kwargs = {
        k: v
        for k, v in engine_kwargs(url, get_settings().database_pooled).items()
        if k not in ("pool_size", "max_overflow")
    }
    connectable = create_async_engine(url, poolclass=pool.NullPool, **kwargs)
    async with connectable.connect() as connection:
        await connection.run_sync(_run)
    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
