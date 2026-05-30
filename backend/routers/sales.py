"""Sales module endpoints — orders, order items, customers, invoices.

Read endpoints (list/detail) require 'view' permission (all roles).
Write endpoints (create order, update status, generate/pay invoice) require
'sales' permission (Admin and Sales/Cashier roles).
"""

from fastapi import APIRouter, Depends, HTTPException

from db import get_db
from deps import require
from schemas import (
    CustomerOut,
    InvoiceCreate,
    InvoiceOut,
    OrderCreate,
    OrderDetail,
    OrderItemOut,
    OrderOut,
    StatusUpdate,
    SuccessResponse,
)

router = APIRouter(prefix="/api", tags=["sales"])

_VALID_TRANSITIONS = {
    "pending":   {"confirmed", "cancelled"},
    "confirmed": {"shipped", "cancelled"},
    "shipped":   {"completed"},
}


# ─────────────────────────────────────────────
# Customers
# ─────────────────────────────────────────────

@router.get("/customers", response_model=list[CustomerOut])
def list_customers(_: dict = Depends(require("view")), db=Depends(get_db)):
    with db.cursor() as cur:
        cur.execute("""
            SELECT customer_id, name, phone, email, address
            FROM   customers
            ORDER BY name
        """)
        return cur.fetchall()


# ─────────────────────────────────────────────
# Orders
# ─────────────────────────────────────────────

@router.get("/orders", response_model=list[OrderOut])
def list_orders(_: dict = Depends(require("view")), db=Depends(get_db)):
    """SL1 — all orders with customer and cashier info."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT o.order_id,
                   c.name          AS customer,
                   u.username      AS processed_by,
                   o.total_amount,
                   o.status,
                   o.created_at
            FROM  orders o
            LEFT JOIN customers c ON c.customer_id = o.customer_id
            JOIN  users u         ON u.user_id      = o.user_id
            ORDER BY o.created_at DESC
        """)
        return cur.fetchall()


@router.get("/orders/{order_id}", response_model=OrderDetail)
def get_order(order_id: int, _: dict = Depends(require("view")), db=Depends(get_db)):
    """SL2 — single order with all line items."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT o.order_id,
                   c.name      AS customer,
                   u.username  AS processed_by,
                   o.total_amount, o.status, o.created_at
            FROM  orders o
            LEFT JOIN customers c ON c.customer_id = o.customer_id
            JOIN  users u         ON u.user_id      = o.user_id
            WHERE o.order_id = %s
        """, (order_id,))
        order = cur.fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        cur.execute("""
            SELECT oi.item_id,
                   p.name      AS product,
                   oi.quantity,
                   oi.unit_price,
                   oi.subtotal
            FROM  order_items oi
            JOIN  products p ON p.product_id = oi.product_id
            WHERE oi.order_id = %s
            ORDER BY oi.item_id
        """, (order_id,))
        items = cur.fetchall()

    return OrderDetail(
        order_id=order["order_id"],
        customer=order["customer"],
        processed_by=order["processed_by"],
        items=[OrderItemOut(**i) for i in items],
        total_amount=float(order["total_amount"]),
        status=order["status"],
        created_at=order["created_at"],
    )


@router.post("/orders", response_model=OrderOut, status_code=201)
def create_order(
    body: OrderCreate,
    user: dict = Depends(require("sales")),
    db=Depends(get_db),
):
    """SL3 — create a new order (stock check → insert order + items → update total → reduce stock).

    The entire operation runs in a single transaction. The connection pool
    commits on success and rolls back on any exception.
    """
    with db.cursor() as cur:
        # 1. Validate stock for every requested item
        for item in body.items:
            cur.execute("""
                SELECT product_id, price, stock_qty, name
                FROM   products
                WHERE  product_id = %s AND is_active = 1
            """, (item.product_id,))
            prod = cur.fetchone()
            if not prod:
                raise HTTPException(
                    status_code=404,
                    detail=f"Product {item.product_id} not found or discontinued",
                )
            if prod["stock_qty"] < item.quantity:
                raise HTTPException(
                    status_code=400,
                    detail=f"Insufficient stock for '{prod['name']}' "
                           f"(requested {item.quantity}, available {prod['stock_qty']})",
                )

        # 2. Create the order row
        cur.execute("""
            INSERT INTO orders (customer_id, user_id, total_amount, status)
            VALUES (%s, %s, 0, 'pending')
            RETURNING order_id, created_at
        """, (body.customer_id, user["out_user_id"]))
        order_row = cur.fetchone()
        order_id = order_row["order_id"]

        # 3. Insert order items (unit_price locked from current product price)
        for item in body.items:
            cur.execute("""
                INSERT INTO order_items (order_id, product_id, quantity, unit_price)
                VALUES (%s, %s, %s,
                        (SELECT price FROM products WHERE product_id = %s))
            """, (order_id, item.product_id, item.quantity, item.product_id))

        # 4. Set order total from computed subtotals
        cur.execute("""
            UPDATE orders
            SET    total_amount = (
                SELECT COALESCE(SUM(subtotal), 0)
                FROM   order_items WHERE order_id = %s
            )
            WHERE  order_id = %s
            RETURNING total_amount
        """, (order_id, order_id))
        total = cur.fetchone()["total_amount"]

        # 5. Reduce product stock
        for item in body.items:
            cur.execute("""
                UPDATE products
                SET    stock_qty = stock_qty - %s
                WHERE  product_id = %s
            """, (item.quantity, item.product_id))

        # 6. Resolve customer name for response
        customer_name = None
        if body.customer_id:
            cur.execute("SELECT name FROM customers WHERE customer_id = %s", (body.customer_id,))
            cust = cur.fetchone()
            customer_name = cust["name"] if cust else None

    db.commit()

    return OrderOut(
        order_id=order_id,
        customer=customer_name,
        processed_by=user["out_username"],
        total_amount=float(total),
        status="pending",
        created_at=order_row["created_at"],
    )


@router.patch("/orders/{order_id}/status", response_model=SuccessResponse)
def update_order_status(
    order_id: int,
    body: StatusUpdate,
    _: dict = Depends(require("sales")),
    db=Depends(get_db),
):
    """SL4/SL5 — advance or cancel an order following allowed transitions."""
    with db.cursor() as cur:
        cur.execute("SELECT status FROM orders WHERE order_id = %s", (order_id,))
        order = cur.fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")

        old_status = order["status"]
        allowed = _VALID_TRANSITIONS.get(old_status, set())
        if body.status not in allowed:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot move from '{old_status}' to '{body.status}'. "
                       f"Allowed: {sorted(allowed) or 'none'}",
            )

        cur.execute("""
            UPDATE orders
            SET    status = %s, updated_at = CURRENT_TIMESTAMP
            WHERE  order_id = %s
        """, (body.status, order_id))

        # Restock products on cancellation!
        if body.status == "cancelled" and old_status != "cancelled":
            cur.execute(
                """
                SELECT product_id, quantity
                FROM   order_items
                WHERE  order_id = %s
                """,
                (order_id,),
            )
            items = cur.fetchall()
            for item in items:
                cur.execute(
                    """
                    UPDATE products
                    SET    stock_qty = stock_qty + %s
                    WHERE  product_id = %s
                    """,
                    (item["quantity"], item["product_id"]),
                )

    db.commit()

    return SuccessResponse(success=True)


# ─────────────────────────────────────────────
# Invoices
# ─────────────────────────────────────────────

@router.get("/invoices", response_model=list[InvoiceOut])
def list_invoices(_: dict = Depends(require("view")), db=Depends(get_db)):
    """SL8 — all invoices with order and customer info."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT i.invoice_id, o.order_id,
                   c.name          AS customer,
                   o.total_amount,
                   i.status,
                   i.issued_at,
                   i.due_date,
                   i.paid_at
            FROM  invoices  i
            JOIN  orders    o ON o.order_id    = i.order_id
            LEFT JOIN customers c ON c.customer_id = o.customer_id
            ORDER BY i.issued_at DESC
        """)
        return cur.fetchall()


@router.post("/invoices", response_model=InvoiceOut, status_code=201)
def create_invoice(
    body: InvoiceCreate,
    _: dict = Depends(require("sales")),
    db=Depends(get_db),
):
    """SL6 — generate an invoice for a completed/confirmed order."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT o.order_id, o.status, o.total_amount,
                   c.name AS customer
            FROM  orders o
            LEFT JOIN customers c ON c.customer_id = o.customer_id
            WHERE o.order_id = %s
        """, (body.order_id,))
        order = cur.fetchone()
        if not order:
            raise HTTPException(status_code=404, detail="Order not found")
        if order["status"] == "cancelled":
            raise HTTPException(status_code=400, detail="Cannot invoice a cancelled order")

        # Check no invoice already exists
        cur.execute("SELECT invoice_id FROM invoices WHERE order_id = %s", (body.order_id,))
        if cur.fetchone():
            raise HTTPException(status_code=409, detail="Invoice already exists for this order")

        cur.execute("""
            INSERT INTO invoices (order_id, due_date, status)
            VALUES (%s, TRUNC(CURRENT_DATE) + %s, 'unpaid')
            RETURNING invoice_id, issued_at, due_date, paid_at, status
        """, (body.order_id, body.due_days))
        inv = cur.fetchone()

    db.commit()

    return InvoiceOut(
        invoice_id=inv["invoice_id"],
        order_id=body.order_id,
        customer=order["customer"],
        total_amount=float(order["total_amount"]),
        status=inv["status"],
        issued_at=inv["issued_at"],
        due_date=inv["due_date"],
        paid_at=inv["paid_at"],
    )


@router.patch("/invoices/{invoice_id}/pay", response_model=SuccessResponse)
def pay_invoice(
    invoice_id: int,
    _: dict = Depends(require("sales")),
    db=Depends(get_db),
):
    """SL7 — mark an invoice as paid."""
    with db.cursor() as cur:
        cur.execute("""
            UPDATE invoices
            SET    paid_at = CURRENT_TIMESTAMP, status = 'paid'
            WHERE  invoice_id = %s AND status = 'unpaid'
            RETURNING order_id
        """, (invoice_id,))
        row = cur.fetchone()
        if not row:
            # Either not found or already paid
            cur.execute("SELECT status FROM invoices WHERE invoice_id = %s", (invoice_id,))
            existing = cur.fetchone()
            if not existing:
                raise HTTPException(status_code=404, detail="Invoice not found")
            raise HTTPException(
                status_code=400,
                detail=f"Invoice is already '{existing['status']}'",
            )

        # Cohesively update the order status to 'confirmed' if it's currently 'pending'
        cur.execute("""
            UPDATE orders
            SET    status = 'confirmed', updated_at = CURRENT_TIMESTAMP
            WHERE  order_id = %s AND status = 'pending'
        """, (row["order_id"],))

    db.commit()

    return SuccessResponse(success=True)
