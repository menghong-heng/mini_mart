"""Customer self-service authentication endpoints.

All credential checks delegate to the PL/pgSQL functions:
    fn_customer_signup           → creates account + opens session
    fn_customer_login            → credential check + opens session
    fn_customer_validate_session → used by get_current_customer dep
    fn_customer_logout           → invalidates session

Password handling: same md5(plaintext) convention as the staff auth router.
"""

import hashlib

from fastapi import APIRouter, Depends, HTTPException, Request
from psycopg import errors

from db import get_db
from deps import extract_bearer, get_current_customer
from schemas import (
    CustomerInfo,
    CustomerLoginRequest,
    CustomerLoginResponse,
    CustomerSignupRequest,
    SuccessResponse,
)

router = APIRouter(prefix="/api/customer", tags=["customer-auth"])


def _md5(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


@router.post("/signup", response_model=CustomerLoginResponse, status_code=201)
def signup(req: CustomerSignupRequest, request: Request, db=Depends(get_db)):
    pw_hash   = _md5(req.password)
    client_ip = request.client.host if request.client else None

    try:
        with db.cursor() as cur:
            cur.execute(
                "SELECT * FROM fn_customer_signup(%s, %s, %s, %s, %s)",
                (req.email, pw_hash, req.full_name, req.phone, client_ip),
            )
            row = cur.fetchone()
    except errors.RaiseException as e:
        msg = e.diag.message_primary or "Signup failed"
        raise HTTPException(status_code=400, detail=msg) from e

    return CustomerLoginResponse(
        token=row["out_token"],
        expires_at=row["out_expires"],
        customer_id=row["out_customer_id"],
        full_name=row["out_full_name"],
        email=req.email,
        phone=row.get("out_phone"),
    )


@router.post("/login", response_model=CustomerLoginResponse)
def login(req: CustomerLoginRequest, request: Request, db=Depends(get_db)):
    pw_hash   = _md5(req.password)
    client_ip = request.client.host if request.client else None

    try:
        with db.cursor() as cur:
            cur.execute(
                "SELECT * FROM fn_customer_login(%s, %s, %s)",
                (req.email, pw_hash, client_ip),
            )
            row = cur.fetchone()
    except errors.RaiseException as e:
        msg = e.diag.message_primary or "Authentication failed"
        raise HTTPException(status_code=401, detail=msg) from e

    if not row:
        raise HTTPException(status_code=401, detail="Authentication failed")

    return CustomerLoginResponse(
        token=row["out_token"],
        expires_at=row["out_expires"],
        customer_id=row["out_customer_id"],
        full_name=row["out_full_name"],
        email=req.email,
        phone=row.get("out_phone"),
    )


@router.post("/logout", response_model=SuccessResponse)
def logout(token: str = Depends(extract_bearer), db=Depends(get_db)):
    with db.cursor() as cur:
        cur.execute("SELECT fn_customer_logout(%s)", (token,))
    return SuccessResponse(success=True)


@router.get("/me", response_model=CustomerInfo)
def me(customer: dict = Depends(get_current_customer)):
    return CustomerInfo(
        customer_id=customer["out_customer_id"],
        email=customer["out_email"],
        full_name=customer["out_full_name"],
        phone=customer.get("out_phone"),
    )
