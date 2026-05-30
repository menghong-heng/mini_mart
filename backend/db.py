"""Oracle connection pool and DB-API compatibility helpers.

The original app was written against another DB-API driver. The route layer
still uses compact `%s` placeholders and dict-like rows, so this module keeps
that public shape while executing against python-oracledb.
"""

from __future__ import annotations

import os
import re
from contextlib import contextmanager
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any
from urllib.parse import unquote, urlparse

import oracledb
from dotenv import load_dotenv

load_dotenv()

DatabaseError = oracledb.DatabaseError
DatabaseIntegrityError = oracledb.IntegrityError

_DEFAULT_USER = "sentineldb"
_DEFAULT_PASSWORD = "sentinelpass"
_DEFAULT_DSN = "localhost:1521/FREEPDB1"

_BOOLEAN_COLUMNS = {
    "is_active",
    "can_admin",
    "can_sales",
    "can_stock",
    "can_view",
    "out_can_admin",
    "out_can_sales",
    "out_can_stock",
    "out_can_view",
    "admin_module",
    "sales_module",
    "stock_module",
    "view_module",
    "inserted",
}


def _settings() -> tuple[str, str, str]:
    """Resolve Oracle settings.

    Preferred env vars:
      ORACLE_USER, ORACLE_PASSWORD, ORACLE_DSN

    A thin `DATABASE_URL` such as
      oracle://sentineldb:sentinelpass@localhost:1521/FREEPDB1
    is also accepted for local convenience.
    """

    database_url = os.getenv("DATABASE_URL")
    if database_url and database_url.lower().startswith("oracle://"):
        parsed = urlparse(database_url)
        user = unquote(parsed.username or _DEFAULT_USER)
        password = unquote(parsed.password or _DEFAULT_PASSWORD)
        port = parsed.port or 1521
        service = parsed.path.lstrip("/") or "FREEPDB1"
        dsn = f"{parsed.hostname or 'localhost'}:{port}/{service}"
        return user, password, dsn

    return (
        os.getenv("ORACLE_USER", _DEFAULT_USER),
        os.getenv("ORACLE_PASSWORD", _DEFAULT_PASSWORD),
        os.getenv("ORACLE_DSN", _DEFAULT_DSN),
    )


def oracle_error_code(exc: BaseException) -> int | None:
    if not getattr(exc, "args", None):
        return None
    error = exc.args[0]
    return getattr(error, "code", None)


def db_error_message(exc: BaseException) -> str:
    if not getattr(exc, "args", None):
        return str(exc)
    error = exc.args[0]
    message = getattr(error, "message", None) or str(exc)
    return re.sub(r"^ORA-\d+:\s*", "", message).strip()


def is_unique_violation(exc: BaseException) -> bool:
    return oracle_error_code(exc) == 1


def is_foreign_key_violation(exc: BaseException) -> bool:
    return oracle_error_code(exc) in {2291, 2292}


def _bind_value(value: Any) -> Any:
    return int(value) if isinstance(value, bool) else value


def _normalize_lob(value: Any) -> Any:
    if hasattr(value, "read"):
        return value.read()
    return value


def _normalize_row(row: dict[str, Any]) -> dict[str, Any]:
    normalized: dict[str, Any] = {}
    for key, value in row.items():
        key = key.lower()
        value = _normalize_lob(value)
        if key.endswith("_date") and isinstance(value, datetime):
            value = value.date()
        elif isinstance(value, datetime) and value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        if key in _BOOLEAN_COLUMNS and value is not None:
            value = bool(value)
        normalized[key] = value
    return normalized


def _replace_keywords_outside_strings(sql: str) -> str:
    """Translate a few legacy SQL tokens used by older route SQL."""

    replacements = {
        "TRUE": "1",
        "FALSE": "0",
        "NOW()": "CURRENT_TIMESTAMP",
        "CLOCK_TIMESTAMP()": "SYSTIMESTAMP",
    }

    output: list[str] = []
    i = 0
    in_string = False
    while i < len(sql):
        char = sql[i]
        if char == "'":
            output.append(char)
            i += 1
            if in_string and i < len(sql) and sql[i] == "'":
                output.append(sql[i])
                i += 1
            else:
                in_string = not in_string
            continue

        if in_string:
            output.append(char)
            i += 1
            continue

        matched = False
        for source, target in replacements.items():
            fragment = sql[i : i + len(source)]
            if fragment.upper() != source:
                continue
            before = sql[i - 1] if i > 0 else " "
            after = sql[i + len(source)] if i + len(source) < len(sql) else " "
            if source in {"TRUE", "FALSE"} and (before.isalnum() or before == "_" or after.isalnum() or after == "_"):
                continue
            output.append(target)
            i += len(source)
            matched = True
            break

        if not matched:
            output.append(char)
            i += 1

    return "".join(output)


def _translate_limit(sql: str, binds: dict[str, Any]) -> str:
    def replace(match: re.Match[str]) -> str:
        token = match.group(1)
        if token.startswith(":"):
            name = token[1:]
            value = int(binds.pop(name))
        else:
            value = int(token)
        return f"FETCH FIRST {value} ROWS ONLY"

    return re.sub(
        r"\bLIMIT\s+(:p\d+|\d+)\b",
        replace,
        sql,
        flags=re.IGNORECASE,
    )


def _ensure_from_dual(sql: str) -> str:
    stripped = sql.strip()
    if stripped.lower().startswith("select ") and " from " not in stripped.lower():
        return f"{stripped} FROM dual"
    return sql


def _adapt_sql_and_params(sql: str, params: Any = None) -> tuple[str, dict[str, Any]]:
    binds: dict[str, Any] = {}
    if params is None:
        adapted = sql
    elif isinstance(params, dict):
        adapted = sql
        binds = {key: _bind_value(value) for key, value in params.items()}
    else:
        adapted = sql
        for index, value in enumerate(params):
            name = f"p{index}"
            adapted = adapted.replace("%s", f":{name}", 1)
            binds[name] = _bind_value(value)

    adapted = _replace_keywords_outside_strings(adapted)
    adapted = _translate_limit(adapted, binds)
    adapted = _ensure_from_dual(adapted)
    return adapted, binds


def _split_returning_columns(columns_sql: str) -> list[tuple[str, str]]:
    columns: list[tuple[str, str]] = []
    for raw_column in columns_sql.split(","):
        expression = raw_column.strip()
        alias_match = re.search(r"\s+AS\s+([A-Za-z_][A-Za-z0-9_]*)$", expression, re.IGNORECASE)
        alias = alias_match.group(1) if alias_match else expression.split(".")[-1]
        columns.append((expression, alias.strip().strip('"').lower()))
    return columns


def _return_var_type(column_name: str) -> Any:
    key = column_name.lower()
    if key in _BOOLEAN_COLUMNS or key.endswith("_id") or key in {"stock_qty", "quantity"}:
        return oracledb.DB_TYPE_NUMBER
    if key.endswith("_amount") or key in {"price", "unit_price", "subtotal"}:
        return oracledb.DB_TYPE_NUMBER
    if key.endswith("_at") or key in {"last_login"}:
        return oracledb.DB_TYPE_TIMESTAMP
    if key.endswith("_date") or key == "due_date":
        return oracledb.DB_TYPE_DATE
    if key in {"description", "config_value", "source", "notes"}:
        return oracledb.DB_TYPE_CLOB
    return oracledb.DB_TYPE_VARCHAR


def _var_value(var: Any) -> Any:
    value = var.getvalue()
    if isinstance(value, list):
        value = value[0] if value else None
    if isinstance(value, Decimal) and value == int(value):
        return int(value)
    return _normalize_lob(value)


class OracleCursor:
    def __init__(self, connection: oracledb.Connection):
        self._cursor = connection.cursor()
        self._result_cursor = None
        self._synthetic_rows: list[dict[str, Any]] | None = None
        self._synthetic_index = 0
        self._rowcount = -1

    def __enter__(self) -> "OracleCursor":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        if self._result_cursor is not None:
            self._result_cursor.close()
        self._cursor.close()

    @property
    def rowcount(self) -> int:
        if self._synthetic_rows is not None:
            return self._rowcount
        return self._cursor.rowcount

    def execute(self, sql: str, params: Any = None) -> "OracleCursor":
        self._result_cursor = None
        self._synthetic_rows = None
        self._synthetic_index = 0
        self._rowcount = -1

        if self._execute_refcursor_function(sql, params):
            return self
        if self._execute_scalar_plsql_function(sql, params):
            return self

        adapted_sql, binds = _adapt_sql_and_params(sql, params)
        returning_match = re.search(r"\bRETURNING\b\s+(.+?)\s*$", adapted_sql, re.IGNORECASE | re.DOTALL)
        if returning_match:
            base_sql = adapted_sql[: returning_match.start()].rstrip()
            columns = _split_returning_columns(returning_match.group(1))
            out_vars: dict[str, Any] = {}
            for index, (_, alias) in enumerate(columns):
                out_vars[f"out_{index}"] = self._cursor.var(_return_var_type(alias))

            returning_sql = (
                f"{base_sql} RETURNING "
                f"{', '.join(expression for expression, _ in columns)} "
                f"INTO {', '.join(':' + name for name in out_vars)}"
            )
            self._cursor.execute(returning_sql, {**binds, **out_vars})
            self._rowcount = self._cursor.rowcount
            self._synthetic_rows = []
            if self._rowcount:
                self._synthetic_rows.append(
                    _normalize_row(
                        {
                            alias: _var_value(out_vars[f"out_{index}"])
                            for index, (_, alias) in enumerate(columns)
                        }
                    )
                )
            return self

        self._cursor.execute(adapted_sql, binds or None)
        if self._cursor.description:
            columns = [description[0].lower() for description in self._cursor.description]
            self._cursor.rowfactory = lambda *args, columns=columns: _normalize_row(dict(zip(columns, args)))
        return self

    def _execute_refcursor_function(self, sql: str, params: Any = None) -> bool:
        match = re.match(r"^\s*SELECT\s+\*\s+FROM\s+(fn_[A-Za-z0-9_]+)\s*\(", sql, re.IGNORECASE)
        if not match:
            return False

        function_name = match.group(1)
        values = list(params or [])
        binds = {f"p{index}": _bind_value(value) for index, value in enumerate(values)}
        result = self._cursor.var(oracledb.CURSOR)
        arg_list = ", ".join(f":p{index}" for index in range(len(values)))
        self._cursor.execute(
            f"BEGIN :result := {function_name}({arg_list}); END;",
            {"result": result, **binds},
        )
        self._result_cursor = result.getvalue()
        if self._result_cursor.description:
            columns = [description[0].lower() for description in self._result_cursor.description]
            self._result_cursor.rowfactory = lambda *args, columns=columns: _normalize_row(dict(zip(columns, args)))
        return True

    def _execute_scalar_plsql_function(self, sql: str, params: Any = None) -> bool:
        match = re.match(
            r"^\s*SELECT\s+(fn_logout|fn_customer_logout|fn_cleanup_sessions)\s*\(",
            sql,
            re.IGNORECASE,
        )
        if not match:
            return False

        function_name = match.group(1)
        values = list(params or [])
        binds = {f"p{index}": _bind_value(value) for index, value in enumerate(values)}
        result = self._cursor.var(oracledb.DB_TYPE_NUMBER)
        arg_list = ", ".join(f":p{index}" for index in range(len(values)))
        self._cursor.execute(
            f"BEGIN :result := {function_name}({arg_list}); END;",
            {"result": result, **binds},
        )
        self._synthetic_rows = [_normalize_row({function_name.lower(): _var_value(result)})]
        self._rowcount = 1
        return True

    def fetchone(self) -> dict[str, Any] | None:
        if self._synthetic_rows is not None:
            if self._synthetic_index >= len(self._synthetic_rows):
                return None
            row = self._synthetic_rows[self._synthetic_index]
            self._synthetic_index += 1
            return row
        if self._result_cursor is not None:
            return self._result_cursor.fetchone()
        return self._cursor.fetchone()

    def fetchall(self) -> list[dict[str, Any]]:
        if self._synthetic_rows is not None:
            rows = self._synthetic_rows[self._synthetic_index :]
            self._synthetic_index = len(self._synthetic_rows)
            return rows
        if self._result_cursor is not None:
            return self._result_cursor.fetchall()
        return self._cursor.fetchall()


class OracleConnection:
    def __init__(self, connection: oracledb.Connection):
        self._connection = connection

    def cursor(self) -> OracleCursor:
        return OracleCursor(self._connection)

    def commit(self) -> None:
        self._connection.commit()

    def rollback(self) -> None:
        self._connection.rollback()

    def close(self) -> None:
        self._connection.close()


class OraclePool:
    def __init__(self) -> None:
        self._pool: oracledb.ConnectionPool | None = None

    def open(self) -> None:
        if self._pool is not None:
            return
        user, password, dsn = _settings()
        self._pool = oracledb.create_pool(
            user=user,
            password=password,
            dsn=dsn,
            min=1,
            max=10,
            increment=1,
            getmode=oracledb.POOL_GETMODE_WAIT,
        )

    def close(self) -> None:
        if self._pool is not None:
            self._pool.close()
            self._pool = None

    @contextmanager
    def connection(self):
        if self._pool is None:
            self.open()
        assert self._pool is not None
        with self._pool.acquire() as connection:
            yield OracleConnection(connection)


def connect() -> OracleConnection:
    user, password, dsn = _settings()
    return OracleConnection(oracledb.connect(user=user, password=password, dsn=dsn))


pool = OraclePool()


def get_db():
    """FastAPI dependency: yields a pooled Oracle connection per request."""

    with pool.connection() as conn:
        try:
            yield conn
        except Exception:
            conn.rollback()
            raise
