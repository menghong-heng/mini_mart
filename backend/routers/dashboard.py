"""Dashboard endpoints — staff-only live activity feed.

Visibility by role:
    Admin   → signups + orders + invoices
    Sales   → signups + orders + invoices
    Cashier → orders  + invoices
    User    → orders only

All staff roles have can_view = TRUE, so the route is gated by
require("view"); the per-role filtering happens inside the handler
based on the role name returned by fn_validate_session.
"""

from fastapi import APIRouter, Depends

from db import get_db
from deps import get_current_user
from schemas import ActivityEntry

router = APIRouter(prefix="/api/dashboard", tags=["dashboard"])


_ROLE_SOURCES = {
    "Admin":   {"signup", "order", "invoice"},
    "Sales":   {"signup", "order", "invoice"},
    "Cashier": {"order", "invoice"},
    "User":    {"order"},
}


_SOURCE_SQL = {
    "signup": """
        SELECT 'signup'      AS type,
               customer_id   AS record_id,
               name          AS label,
               created_at
        FROM   customers
    """,
    "order": """
        SELECT 'order'                                  AS type,
               o.order_id                               AS record_id,
               'Order #' || o.order_id
                   || COALESCE(' — ' || c.name, '')     AS label,
               o.created_at
        FROM   orders o
        LEFT   JOIN customers c ON c.customer_id = o.customer_id
    """,
    "invoice": """
        SELECT 'invoice'                                AS type,
               i.invoice_id                             AS record_id,
               'Invoice #' || i.invoice_id
                   || COALESCE(' — ' || c.name, '')     AS label,
               i.issued_at                              AS created_at
        FROM   invoices i
        JOIN   orders   o ON o.order_id    = i.order_id
        LEFT   JOIN customers c ON c.customer_id = o.customer_id
    """,
}


@router.get("/activity", response_model=list[ActivityEntry])
def dashboard_activity(
    user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """Last 20 records across customer signups, orders, and invoices.

    The visible set of sources is determined by the caller's role. If the
    role is unknown (a custom role not in `_ROLE_SOURCES`), we fall back
    to orders only — the minimum any staff member sees.
    """
    sources = _ROLE_SOURCES.get(user["out_role"], {"order"})
    if not sources:
        return []

    sub_queries = [_SOURCE_SQL[s] for s in sources]
    union_sql = " UNION ALL ".join(sub_queries)
    query = f"""
        SELECT type, record_id, label, created_at
        FROM ({union_sql}) feed
        ORDER BY created_at DESC
        LIMIT 20
    """

    with db.cursor() as cur:
        cur.execute(query)
        return cur.fetchall()
