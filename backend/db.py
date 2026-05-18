"""PostgreSQL connection pool.

Uses psycopg3 with dict_row so every fetchone()/fetchall() returns dicts —
this matches how the route handlers access columns by name.
"""

import os
from dotenv import load_dotenv
from psycopg_pool import ConnectionPool
from psycopg.rows import dict_row

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:postgres@localhost:5432/sentineldb",
)

pool = ConnectionPool(
    DATABASE_URL,
    min_size=1,
    max_size=10,
    kwargs={"row_factory": dict_row},
    open=False,
)


def get_db():
    """FastAPI dependency: yields a pooled connection per request.

    The connection commits on success and rolls back on exception,
    then is returned to the pool.
    """
    with pool.connection() as conn:
        yield conn
