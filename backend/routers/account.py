"""Account module endpoints — users, roles, active sessions.

All write endpoints require the 'admin' permission.
GET /api/roles and GET /api/sessions are also admin-only because
listing active sessions is sensitive information.
"""

import hashlib

from fastapi import APIRouter, Depends, HTTPException
from psycopg import errors

from db import get_db
from deps import get_current_user, require
from schemas import (
    ActiveToggle,
    RoleAssign,
    RoleOut,
    SessionOut,
    SuccessResponse,
    UserCreate,
    UserOut,
)

router = APIRouter(prefix="/api/users", tags=["account"])
role_router = APIRouter(prefix="/api/roles", tags=["account"])
session_router = APIRouter(prefix="/api/sessions", tags=["account"])


def _md5(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


# ─────────────────────────────────────────────
# Users
# ─────────────────────────────────────────────

@router.get("", response_model=list[UserOut])
def list_users(
    _: dict = Depends(require("admin")),
    db=Depends(get_db),
):
    """A1 — all users with role."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT u.user_id, u.username, r.role_name,
                   u.is_active, u.created_at, u.last_login
            FROM   users u
            JOIN   roles r ON r.role_id = u.role_id
            ORDER BY u.user_id
        """)
        return cur.fetchall()


@router.post("", response_model=UserOut, status_code=201)
def create_user(
    body: UserCreate,
    _: dict = Depends(require("admin")),
    db=Depends(get_db),
):
    """A7 — add a new user."""
    with db.cursor() as cur:
        # Verify the role name exists
        cur.execute("SELECT role_id FROM roles WHERE role_name = %s", (body.role_name,))
        role = cur.fetchone()
        if not role:
            raise HTTPException(status_code=404, detail=f"Role '{body.role_name}' not found")

        try:
            cur.execute("""
                INSERT INTO users (username, password_hash, role_id, is_active)
                VALUES (%s, %s, %s, TRUE)
                RETURNING user_id, username, is_active, created_at, last_login
            """, (body.username, _md5(body.password), role["role_id"]))
        except errors.UniqueViolation:
            raise HTTPException(status_code=409, detail=f"Username '{body.username}' already exists")

        row = cur.fetchone()

    return {**row, "role_name": body.role_name}


@router.patch("/{user_id}/role", response_model=SuccessResponse)
def reassign_role(
    user_id: int,
    body: RoleAssign,
    _: dict = Depends(require("admin")),
    db=Depends(get_db),
):
    """A5 — change a user's role."""
    with db.cursor() as cur:
        cur.execute("SELECT role_id FROM roles WHERE role_name = %s", (body.role_name,))
        role = cur.fetchone()
        if not role:
            raise HTTPException(status_code=404, detail=f"Role '{body.role_name}' not found")

        cur.execute(
            "UPDATE users SET role_id = %s WHERE user_id = %s",
            (role["role_id"], user_id),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="User not found")

    return SuccessResponse(success=True)


@router.patch("/{user_id}/active", response_model=SuccessResponse)
def toggle_active(
    user_id: int,
    body: ActiveToggle,
    _: dict = Depends(require("admin")),
    db=Depends(get_db),
):
    """A6 — activate or deactivate a user account."""
    with db.cursor() as cur:
        cur.execute(
            "UPDATE users SET is_active = %s WHERE user_id = %s",
            (body.is_active, user_id),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="User not found")

        if not body.is_active:
            # Force-expire all active sessions for this user (A9)
            cur.execute(
                "UPDATE sessions SET is_active = FALSE WHERE user_id = %s AND is_active = TRUE",
                (user_id,),
            )

    return SuccessResponse(success=True)


# ─────────────────────────────────────────────
# Roles
# ─────────────────────────────────────────────

@role_router.get("", response_model=list[RoleOut])
def list_roles(_: dict = Depends(get_current_user), db=Depends(get_db)):
    """A10 — full permission matrix for all roles."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT role_id, role_name,
                   can_admin, can_sales, can_stock, can_view
            FROM   roles
            ORDER BY role_id
        """)
        return cur.fetchall()


# ─────────────────────────────────────────────
# Active sessions
# ─────────────────────────────────────────────

@session_router.get("", response_model=list[SessionOut])
def list_sessions(
    _: dict = Depends(require("admin")),
    db=Depends(get_db),
):
    """A8 — all currently active sessions."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT s.session_id, u.username, r.role_name,
                   s.ip_address, s.created_at, s.expires_at
            FROM   sessions s
            JOIN   users u ON u.user_id = s.user_id
            JOIN   roles r ON r.role_id = u.role_id
            WHERE  s.is_active  = TRUE
              AND  s.expires_at > NOW()
            ORDER BY s.created_at DESC
        """)
        return cur.fetchall()
