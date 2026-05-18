"""FastAPI application entry point.

To run (from inside the backend/ directory):

    python -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    cp .env.example .env
    # edit .env if your local PostgreSQL credentials differ
    uvicorn main:app --reload --port 8000

Then open http://localhost:8000/docs for the Swagger UI.

Prerequisites:
    The PostgreSQL database referenced by DATABASE_URL must already have:
      - schema/schema.sql loaded
      - data/seed.sql loaded
      - queries/auth.sql loaded
      - queries/permissions.sql loaded
"""

import os

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from db import pool
from routers import auth
from routers import customer_auth
from routers.account import router as account_router
from routers.account import role_router, session_router
from routers.stock import router as stock_router
from routers.sales import router as sales_router
from routers.admin import router as admin_router
from routers.shop import router as shop_router
from routers.dashboard import router as dashboard_router

load_dotenv()

FRONTEND_ORIGIN = os.getenv("FRONTEND_ORIGIN", "http://localhost:5173")

app = FastAPI(
    title="SentinelDB API",
    version="0.1.0",
    description="DB-centric RBAC server — every permission check delegates to PL/pgSQL.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[FRONTEND_ORIGIN],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def _open_pool():
    pool.open()


@app.on_event("shutdown")
def _close_pool():
    pool.close()


@app.get("/", tags=["meta"])
def root():
    return {"name": "SentinelDB API", "version": app.version, "status": "ok"}


@app.get("/health", tags=["meta"])
def health():
    with pool.connection() as conn, conn.cursor() as cur:
        cur.execute("SELECT 1 AS ok")
        row = cur.fetchone()
    return {"database": "up" if row and row["ok"] == 1 else "down"}


app.include_router(auth.router)
app.include_router(customer_auth.router)
app.include_router(shop_router)
app.include_router(account_router)
app.include_router(role_router)
app.include_router(session_router)
app.include_router(stock_router)
app.include_router(sales_router)
app.include_router(admin_router)
app.include_router(dashboard_router)
