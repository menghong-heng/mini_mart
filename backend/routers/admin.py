"""Admin module endpoints — audit logs, system config, reports.

All endpoints require 'admin' permission (Admin role only).
"""

from fastapi import APIRouter, Depends, HTTPException, Query

from db import get_db
from deps import require
from schemas import AuditLogOut, ConfigOut, ConfigUpdate, RevenueRow, SummaryRow

router = APIRouter(prefix="/api", tags=["admin"])


# ─────────────────────────────────────────────
# Audit logs
# ─────────────────────────────────────────────

@router.get("/audit-logs", response_model=list[AuditLogOut])
def list_audit_logs(
    action: str | None = Query(default=None, description="Filter by action, e.g. LOGIN"),
    limit: int = Query(default=200, le=1000),
    _: dict = Depends(require("admin")),
    db=Depends(get_db),
):
    """AD1/AD2 — audit log, most recent first, optional action filter."""
    with db.cursor() as cur:
        if action:
            cur.execute("""
                SELECT al.log_id,
                       COALESCE(u.username, '(deleted)') AS actor,
                       al.action, al.table_affected,
                       al.record_id, al.ip_address, al.timestamp
                FROM  audit_logs al
                LEFT JOIN users u ON u.user_id = al.user_id
                WHERE al.action = %s
                ORDER BY al.timestamp DESC
                LIMIT %s
            """, (action.upper(), limit))
        else:
            cur.execute("""
                SELECT al.log_id,
                       COALESCE(u.username, '(deleted)') AS actor,
                       al.action, al.table_affected,
                       al.record_id, al.ip_address, al.timestamp
                FROM  audit_logs al
                LEFT JOIN users u ON u.user_id = al.user_id
                ORDER BY al.timestamp DESC
                LIMIT %s
            """, (limit,))
        return cur.fetchall()


# ─────────────────────────────────────────────
# System config
# ─────────────────────────────────────────────

@router.get("/system-config", response_model=list[ConfigOut])
def list_config(_: dict = Depends(require("admin")), db=Depends(get_db)):
    """AD7 — all system configuration settings."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT sc.config_key, sc.config_value, sc.description,
                   sc.updated_at,
                   COALESCE(u.username, '(deleted)') AS updated_by
            FROM  system_config sc
            LEFT JOIN users u ON u.user_id = sc.updated_by
            ORDER BY sc.config_key
        """)
        return cur.fetchall()


@router.patch("/system-config/{config_key}", response_model=ConfigOut)
def update_config(
    config_key: str,
    body: ConfigUpdate,
    user: dict = Depends(require("admin")),
    db=Depends(get_db),
):
    """AD9 — update a single configuration value."""
    with db.cursor() as cur:
        cur.execute("""
            UPDATE system_config
            SET    config_value = %s,
                   updated_at   = NOW(),
                   updated_by   = %s
            WHERE  config_key = %s
            RETURNING config_key, config_value, description, updated_at
        """, (body.config_value, user["out_user_id"], config_key))

        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Config key '{config_key}' not found")

        row = cur.fetchone()

    return ConfigOut(
        config_key=row["config_key"],
        config_value=row["config_value"],
        description=row["description"],
        updated_at=row["updated_at"],
        updated_by=user["out_username"],
    )


# ─────────────────────────────────────────────
# Reports
# ─────────────────────────────────────────────

@router.get("/reports/summary", response_model=list[SummaryRow])
def summary_report(_: dict = Depends(require("admin")), db=Depends(get_db)):
    """AD12 — 10-metric system snapshot."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT 'Total Users'      AS metric, COUNT(*)::TEXT AS value FROM users
            UNION ALL
            SELECT 'Active Users',    COUNT(*)::TEXT FROM users   WHERE is_active = TRUE
            UNION ALL
            SELECT 'Total Products',  COUNT(*)::TEXT FROM products
            UNION ALL
            SELECT 'Active Products', COUNT(*)::TEXT FROM products WHERE is_active = TRUE
            UNION ALL
            SELECT 'Total Customers', COUNT(*)::TEXT FROM customers
            UNION ALL
            SELECT 'Total Orders',    COUNT(*)::TEXT FROM orders
            UNION ALL
            SELECT 'Completed Orders',COUNT(*)::TEXT FROM orders   WHERE status = 'completed'
            UNION ALL
            SELECT 'Unpaid Invoices', COUNT(*)::TEXT FROM invoices WHERE status = 'unpaid'
            UNION ALL
            SELECT 'Active Sessions', COUNT(*)::TEXT FROM sessions
                WHERE is_active = TRUE AND expires_at > NOW()
            UNION ALL
            SELECT 'Audit Log Entries', COUNT(*)::TEXT FROM audit_logs
        """)
        return cur.fetchall()


@router.get("/reports/revenue", response_model=list[RevenueRow])
def revenue_report(_: dict = Depends(require("admin")), db=Depends(get_db)):
    """AD10 — gross and confirmed revenue grouped by date."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT
                DATE(o.created_at)                                            AS sale_date,
                COUNT(o.order_id)                                             AS orders_placed,
                COALESCE(SUM(o.total_amount), 0)                             AS gross_revenue,
                COALESCE(SUM(o.total_amount) FILTER (WHERE o.status = 'completed'), 0)
                                                                              AS confirmed_revenue
            FROM  orders o
            GROUP BY DATE(o.created_at)
            ORDER BY sale_date DESC
        """)
        return cur.fetchall()
