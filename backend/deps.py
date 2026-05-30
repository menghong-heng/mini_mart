"""FastAPI dependencies for auth + RBAC.

All RBAC logic delegates to the database PL/SQL functions:
    fn_validate_session(token)            → returns user + role flags
    fn_check_permission(token, module)    → returns boolean
"""

from fastapi import Depends, HTTPException, Header

from db import get_db


def extract_bearer(authorization: str | None = Header(default=None)) -> str:
    """Pull the token out of the `Authorization: Bearer <token>` header."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing or malformed bearer token")
    return authorization.split(" ", 1)[1].strip()


def get_current_user(
    token: str = Depends(extract_bearer),
    db=Depends(get_db),
) -> dict:
    """Validate the session token via fn_validate_session.

    Returns the joined user+role row from the DB function, plus the raw token
    so downstream dependencies (e.g., `require`) can re-use it for permission
    checks without re-extracting the header.
    """
    with db.cursor() as cur:
        cur.execute("SELECT * FROM fn_validate_session(%s)", (token,))
        row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    return {**row, "token": token}


def require(module: str):
    """Dependency factory: enforce that the session can access `module`.

    Usage:
        @router.get("/audit-logs", dependencies=[Depends(require("admin"))])
    """
    if module not in {"admin", "sales", "stock", "view"}:
        raise ValueError(f"Unknown module name: {module!r}")

    def _dep(
        user: dict = Depends(get_current_user),
        db=Depends(get_db),
    ) -> dict:
        with db.cursor() as cur:
            cur.execute("SELECT fn_check_permission(%s, %s) AS fn_check_permission", (user["token"], module))
            allowed = cur.fetchone()["fn_check_permission"]
        if not allowed:
            raise HTTPException(
                status_code=403,
                detail=f"Role '{user['out_role']}' is not allowed to access the '{module}' module",
            )
        return user

    return _dep


def get_current_customer(
    token: str = Depends(extract_bearer),
    db=Depends(get_db),
) -> dict:
    """Validate a customer session token via fn_customer_validate_session.

    Completely separate from the staff get_current_user — different tables,
    different functions, different token namespace.
    """
    with db.cursor() as cur:
        cur.execute("SELECT * FROM fn_customer_validate_session(%s)", (token,))
        row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid or expired customer session")
    return {**row, "token": token}
