"""Public shop endpoints + customer-authenticated order history.

GET /api/shop/products           — public, no auth required
GET /api/shop/orders/mine        — customer auth required
GET /api/shop/orders/{order_id}  — customer auth, must own the order
"""

from fastapi import APIRouter, Depends, HTTPException

from db import get_db
from deps import get_current_customer
from schemas import (
    ShopOrderCreate,
    ShopOrderCreated,
    ShopOrderDetail,
    ShopOrderOut,
    ShopProductOut,
)

router = APIRouter(prefix="/api/shop", tags=["shop"])


@router.get("/products", response_model=list[ShopProductOut])
def shop_products(db=Depends(get_db)):
    """Public product catalog — active products with stock > 0."""
    with db.cursor() as cur:
        cur.execute(
            """
            SELECT p.product_id,
                   p.name,
                   c.name  AS category,
                   p.price,
                   p.stock_qty,
                   p.image_url
            FROM   products p
            LEFT   JOIN categories c ON c.category_id = p.category_id
            WHERE  p.is_active  = TRUE
              AND  p.stock_qty  > 0
            ORDER  BY c.name NULLS LAST, p.name
            """
        )
        return cur.fetchall()


@router.post("/orders", response_model=ShopOrderCreated, status_code=201)
def create_my_order(
    body: ShopOrderCreate,
    customer: dict = Depends(get_current_customer),
    db=Depends(get_db),
):
    """Place an order on behalf of the authenticated customer.

    Stock check → insert order (user_id NULL, customer self-service) →
    insert items → recompute total → deduct stock → auto-issue unpaid
    invoice. Runs in a single transaction; the pool commits on success
    and rolls back on error.
    """
    customer_id = customer["out_customer_id"]

    with db.cursor() as cur:
        for item in body.items:
            cur.execute(
                """
                SELECT product_id, stock_qty, name
                FROM   products
                WHERE  product_id = %s AND is_active = TRUE
                """,
                (item.product_id,),
            )
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

        cur.execute(
            """
            INSERT INTO orders (customer_id, user_id, total_amount, status)
            VALUES (%s, NULL, 0, 'pending')
            RETURNING order_id, created_at
            """,
            (customer_id,),
        )
        order_row = cur.fetchone()
        order_id = order_row["order_id"]

        for item in body.items:
            cur.execute(
                """
                INSERT INTO order_items (order_id, product_id, quantity, unit_price)
                VALUES (%s, %s, %s,
                        (SELECT price FROM products WHERE product_id = %s))
                """,
                (order_id, item.product_id, item.quantity, item.product_id),
            )

        cur.execute(
            """
            UPDATE orders
            SET    total_amount = (
                SELECT COALESCE(SUM(subtotal), 0)
                FROM   order_items WHERE order_id = %s
            )
            WHERE  order_id = %s
            RETURNING total_amount
            """,
            (order_id, order_id),
        )
        total = cur.fetchone()["total_amount"]

        for item in body.items:
            cur.execute(
                """
                UPDATE products
                SET    stock_qty = stock_qty - %s
                WHERE  product_id = %s
                """,
                (item.quantity, item.product_id),
            )

        cur.execute(
            """
            INSERT INTO invoices (order_id, due_date, status)
            VALUES (%s, CURRENT_DATE + 14, 'unpaid')
            """,
            (order_id,),
        )

    db.commit()

    return ShopOrderCreated(
        order_id=order_id,
        total_amount=float(total),
        status="pending",
    )


@router.post("/orders/{order_id}/pay", response_model=ShopOrderCreated)
def pay_my_order(
    order_id: int,
    customer: dict = Depends(get_current_customer),
    db=Depends(get_db),
):
    """Pay an unpaid order belonging to the authenticated customer.

    Marks the invoice as paid and advances the order status to 'confirmed'.
    """
    customer_id = customer["out_customer_id"]
    with db.cursor() as cur:
        cur.execute(
            """
            SELECT o.order_id, o.status, o.total_amount, i.status AS invoice_status
            FROM   orders o
            LEFT   JOIN invoices i ON i.order_id = o.order_id
            WHERE  o.order_id = %s AND o.customer_id = %s
            """,
            (order_id, customer_id),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Order not found")

        if row["invoice_status"] == "paid":
            raise HTTPException(status_code=400, detail="Order is already paid")

        cur.execute(
            """
            UPDATE invoices
            SET    paid_at = NOW(), status = 'paid'
            WHERE  order_id = %s AND status = 'unpaid'
            """,
            (order_id,),
        )

        cur.execute(
            """
            UPDATE orders
            SET    status = 'confirmed', updated_at = NOW()
            WHERE  order_id = %s AND status = 'pending'
            """,
            (order_id,),
        )

    db.commit()

    return ShopOrderCreated(
        order_id=order_id,
        total_amount=float(row["total_amount"]),
        status="confirmed",
    )


@router.get("/orders/mine", response_model=list[ShopOrderOut])
def my_orders(customer: dict = Depends(get_current_customer), db=Depends(get_db)):
    """List all orders belonging to the authenticated customer."""
    with db.cursor() as cur:
        cur.execute(
            """
            SELECT o.order_id,
                   o.total_amount,
                   o.status,
                   o.created_at,
                   COALESCE(i.status, 'no invoice') AS invoice_status
            FROM   orders   o
            LEFT   JOIN invoices i ON i.order_id = o.order_id
            WHERE  o.customer_id = %s
            ORDER  BY o.created_at DESC
            """,
            (customer["out_customer_id"],),
        )
        return cur.fetchall()


@router.get("/orders/{order_id}", response_model=ShopOrderDetail)
def get_my_order(order_id: int, customer: dict = Depends(get_current_customer), db=Depends(get_db)):
    """Single order detail — returns 404 if the order does not belong to this customer."""
    with db.cursor() as cur:
        cur.execute(
            """
            SELECT o.order_id,
                   o.total_amount,
                   o.status,
                   o.created_at,
                   COALESCE(i.status, 'no invoice') AS invoice_status
            FROM   orders   o
            LEFT   JOIN invoices i ON i.order_id = o.order_id
            WHERE  o.order_id    = %s
              AND  o.customer_id = %s
            """,
            (order_id, customer["out_customer_id"]),
        )
        order = cur.fetchone()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    with db.cursor() as cur:
        cur.execute(
            """
            SELECT oi.item_id,
                   p.name   AS product,
                   oi.quantity,
                   oi.unit_price,
                   oi.subtotal
            FROM   order_items oi
            JOIN   products    p  ON p.product_id = oi.product_id
            WHERE  oi.order_id = %s
            ORDER  BY oi.item_id
            """,
            (order_id,),
        )
        items = cur.fetchall()

    return {**order, "items": items}
