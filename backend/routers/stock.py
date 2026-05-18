"""Stock module endpoints — products, categories, suppliers.

Read endpoints require 'view' permission (all roles).
Write endpoints (create, restock, discontinue) require 'stock' permission
(Admin and Sales roles only).
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import errors

from db import get_db
from deps import get_current_user, require
from schemas import (
    CategoryOut,
    ProductCreate,
    ProductOut,
    ProductRestock,
    SuccessResponse,
    SupplierOut,
)

router = APIRouter(prefix="/api", tags=["stock"])


# ─────────────────────────────────────────────
# Products
# ─────────────────────────────────────────────

@router.get("/products", response_model=list[ProductOut])
def list_products(
    active_only: bool = Query(default=True),
    _: dict = Depends(require("view")),
    db=Depends(get_db),
):
    """S1 — product listing with category and supplier names."""
    with db.cursor() as cur:
        sql = """
            SELECT p.product_id, p.name,
                   c.name  AS category,
                   p.price, p.stock_qty,
                   s.name  AS supplier,
                   p.is_active
            FROM  products p
            LEFT JOIN categories c ON c.category_id = p.category_id
            LEFT JOIN suppliers  s ON s.supplier_id  = p.supplier_id
        """
        if active_only:
            sql += " WHERE p.is_active = TRUE"
        sql += " ORDER BY c.name NULLS LAST, p.name"
        cur.execute(sql)
        return cur.fetchall()


@router.get("/products/low-stock", response_model=list[ProductOut])
def low_stock(
    threshold: int = Query(default=100, ge=1),
    _: dict = Depends(require("stock")),
    db=Depends(get_db),
):
    """S2 — products whose stock_qty is below the given threshold."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT p.product_id, p.name,
                   c.name  AS category,
                   p.price, p.stock_qty,
                   s.name  AS supplier,
                   p.is_active
            FROM  products p
            LEFT JOIN categories c ON c.category_id = p.category_id
            LEFT JOIN suppliers  s ON s.supplier_id  = p.supplier_id
            WHERE p.is_active = TRUE
              AND p.stock_qty < %s
            ORDER BY p.stock_qty ASC
        """, (threshold,))
        return cur.fetchall()


@router.post("/products", response_model=ProductOut, status_code=201)
def create_product(
    body: ProductCreate,
    _: dict = Depends(require("stock")),
    db=Depends(get_db),
):
    """S9 — add a new product."""
    with db.cursor() as cur:
        try:
            cur.execute("""
                INSERT INTO products (name, category_id, price, stock_qty, supplier_id, is_active)
                VALUES (%s, %s, %s, %s, %s, TRUE)
                RETURNING product_id, name, price, stock_qty, is_active,
                          category_id, supplier_id
            """, (body.name, body.category_id, body.price, body.stock_qty, body.supplier_id))
        except errors.ForeignKeyViolation as e:
            raise HTTPException(status_code=400, detail="Invalid category_id or supplier_id") from e

        row = cur.fetchone()

        # Resolve names for the response
        category = None
        if row["category_id"]:
            cur.execute("SELECT name FROM categories WHERE category_id = %s", (row["category_id"],))
            cat = cur.fetchone()
            category = cat["name"] if cat else None

        supplier = None
        if row["supplier_id"]:
            cur.execute("SELECT name FROM suppliers WHERE supplier_id = %s", (row["supplier_id"],))
            sup = cur.fetchone()
            supplier = sup["name"] if sup else None

    return ProductOut(
        product_id=row["product_id"],
        name=row["name"],
        category=category,
        price=float(row["price"]),
        stock_qty=row["stock_qty"],
        supplier=supplier,
        is_active=row["is_active"],
    )


@router.patch("/products/{product_id}/restock", response_model=ProductOut)
def restock_product(
    product_id: int,
    body: ProductRestock,
    _: dict = Depends(require("stock")),
    db=Depends(get_db),
):
    """S8 — add units to a product's stock_qty."""
    with db.cursor() as cur:
        cur.execute("""
            UPDATE products
            SET    stock_qty = stock_qty + %s
            WHERE  product_id = %s
            RETURNING product_id, name, price, stock_qty, is_active,
                      category_id, supplier_id
        """, (body.add_qty, product_id))

        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Product not found")

        row = cur.fetchone()

        category = None
        if row["category_id"]:
            cur.execute("SELECT name FROM categories WHERE category_id = %s", (row["category_id"],))
            cat = cur.fetchone()
            category = cat["name"] if cat else None

        supplier = None
        if row["supplier_id"]:
            cur.execute("SELECT name FROM suppliers WHERE supplier_id = %s", (row["supplier_id"],))
            sup = cur.fetchone()
            supplier = sup["name"] if sup else None

    return ProductOut(
        product_id=row["product_id"],
        name=row["name"],
        category=category,
        price=float(row["price"]),
        stock_qty=row["stock_qty"],
        supplier=supplier,
        is_active=row["is_active"],
    )


@router.patch("/products/{product_id}/discontinue", response_model=SuccessResponse)
def discontinue_product(
    product_id: int,
    _: dict = Depends(require("stock")),
    db=Depends(get_db),
):
    """S10 — mark a product inactive (discontinued)."""
    with db.cursor() as cur:
        cur.execute(
            "UPDATE products SET is_active = FALSE WHERE product_id = %s",
            (product_id,),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Product not found")

    return SuccessResponse(success=True)


# ─────────────────────────────────────────────
# Categories
# ─────────────────────────────────────────────

@router.get("/categories", response_model=list[CategoryOut])
def list_categories(_: dict = Depends(require("view")), db=Depends(get_db)):
    with db.cursor() as cur:
        cur.execute("SELECT category_id, name, description FROM categories ORDER BY name")
        return cur.fetchall()


# ─────────────────────────────────────────────
# Suppliers
# ─────────────────────────────────────────────

@router.get("/suppliers", response_model=list[SupplierOut])
def list_suppliers(_: dict = Depends(require("stock")), db=Depends(get_db)):
    """S7 — supplier contact list."""
    with db.cursor() as cur:
        cur.execute("""
            SELECT supplier_id, name, contact_name, phone, email, address
            FROM   suppliers
            ORDER BY name
        """)
        return cur.fetchall()
