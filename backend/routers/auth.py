"""Authentication endpoints: login, logout, current-user lookup.

All three delegate to the existing PL/pgSQL functions:
    fn_login           — credential check + opens a session row
    fn_validate_session — checks the token is still valid
    fn_logout          — flips the session row to is_active = FALSE

Password handling:
    The seed data stores passwords as md5(plaintext). The login endpoint
    hashes the incoming plaintext with md5 before calling fn_login so the
    comparison matches what's stored. This is FOR DEMO ONLY — production
    should use bcrypt via pgcrypto.crypt().
"""

import hashlib

from fastapi import APIRouter, Depends, HTTPException, Request
from psycopg import errors

from db import get_db
from deps import get_current_user
from schemas import LoginRequest, LoginResponse, Permissions, SuccessResponse, UserInfo

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _md5(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


@router.post("/login", response_model=LoginResponse)
def login(req: LoginRequest, request: Request, db=Depends(get_db)):
    password_md5 = _md5(req.password)
    client_ip = request.client.host if request.client else None

    try:
        with db.cursor() as cur:
            cur.execute(
                "SELECT * FROM fn_login(%s, %s, %s)",
                (req.username, password_md5, client_ip),
            )
            row = cur.fetchone()
    except errors.RaiseException as e:
        # fn_login raises 'AUTH_FAIL: ...' for bad credentials or disabled account
        message = e.diag.message_primary or "Authentication failed"
        raise HTTPException(status_code=401, detail=message) from e

    if not row:
        raise HTTPException(status_code=401, detail="Authentication failed")

    db.commit()

    return LoginResponse(
        token=row["out_token"],
        expires_at=row["out_expires"],
        role=row["out_role"],
        permissions=Permissions(
            admin=row["out_can_admin"],
            sales=row["out_can_sales"],
            stock=row["out_can_stock"],
            view=row["out_can_view"],
        ),
    )


@router.post("/logout", response_model=SuccessResponse)
def logout(user: dict = Depends(get_current_user), db=Depends(get_db)):
    with db.cursor() as cur:
        cur.execute("SELECT fn_logout(%s)", (user["token"],))
    db.commit()
    return SuccessResponse(success=True)


@router.get("/me", response_model=UserInfo)
def me(user: dict = Depends(get_current_user)):
    return UserInfo(
        user_id=user["out_user_id"],
        username=user["out_username"],
        role=user["out_role"],
        permissions=Permissions(
            admin=user["out_can_admin"],
            sales=user["out_can_sales"],
            stock=user["out_can_stock"],
            view=user["out_can_view"],
        ),
    )
