"""Stock module endpoints: products, categories, suppliers, and product images.

Read endpoints require 'view' permission (all roles).
Write endpoints require 'stock' permission (Admin and Sales roles only).
"""

import re
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile

from db import DatabaseIntegrityError, get_db, is_foreign_key_violation
from deps import require
from schemas import (
    CategoryOut,
    ProductCreate,
    ProductImageAssign,
    ProductImageOut,
    ProductOut,
    ProductRestock,
    SuccessResponse,
    SupplierOut,
)

router = APIRouter(prefix="/api", tags=["stock"])

PRODUCT_IMAGE_DIR = Path(__file__).resolve().parent.parent / "static" / "product-images"
ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}
MAX_IMAGE_BYTES = 5 * 1024 * 1024

PRODUCT_SELECT = """
    SELECT p.product_id, p.name,
           c.name AS category,
           p.price, p.stock_qty,
           s.name AS supplier,
           p.image_url,
           p.is_active
    FROM   products p
    LEFT   JOIN categories c ON c.category_id = p.category_id
    LEFT   JOIN suppliers  s ON s.supplier_id = p.supplier_id
"""


def _fetch_product(cur, product_id: int):
    cur.execute(PRODUCT_SELECT + " WHERE p.product_id = %s", (product_id,))
    return cur.fetchone()


def _safe_filename(label: str, original_name: str) -> str:
    ext = Path(original_name or "").suffix.lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
        ext = ".jpg"
    stem = re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-")[:40] or "product"
    return f"{uuid.uuid4().hex}-{stem}{ext}"


def _register_product_image(cur, label: str, image_url: str | None, source: str | None = None):
    if not image_url:
        return
    cur.execute(
        """
        MERGE INTO product_images target
        USING (
            SELECT %s AS label, %s AS image_url, %s AS source FROM dual
        ) source
        ON (target.image_url = source.image_url)
        WHEN NOT MATCHED THEN
            INSERT (label, image_url, source)
            VALUES (source.label, source.image_url, source.source)
        """,
        (label, image_url, source),
    )


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
        sql = PRODUCT_SELECT
        if active_only:
            sql += " WHERE p.is_active = 1"
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
        cur.execute(
            PRODUCT_SELECT
            + """
            WHERE p.is_active = 1
              AND p.stock_qty < %s
            ORDER BY p.stock_qty ASC
            """,
            (threshold,),
        )
        return cur.fetchall()


@router.post("/products", response_model=ProductOut, status_code=201)
def create_product(
    body: ProductCreate,
    _: dict = Depends(require("stock")),
    db=Depends(get_db),
):
    """S9 — add a new product."""
    image_url = (body.image_url or "").strip() or None
    with db.cursor() as cur:
        try:
            cur.execute(
                """
                INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active)
                VALUES (%s, %s, %s, %s, %s, %s, 1)
                RETURNING product_id
                """,
                (body.name, body.category_id, body.price, body.stock_qty, body.supplier_id, image_url),
            )
        except DatabaseIntegrityError as e:
            if is_foreign_key_violation(e):
                raise HTTPException(status_code=400, detail="Invalid category_id or supplier_id") from e
            raise

        product_id = cur.fetchone()["product_id"]
        _register_product_image(cur, body.name, image_url, "Registered during product create")
        row = _fetch_product(cur, product_id)

    db.commit()
    return row


@router.patch("/products/{product_id}/restock", response_model=ProductOut)
def restock_product(
    product_id: int,
    body: ProductRestock,
    _: dict = Depends(require("stock")),
    db=Depends(get_db),
):
    """S8 — add units to a product's stock_qty."""
    with db.cursor() as cur:
        cur.execute(
            """
            UPDATE products
            SET    stock_qty = stock_qty + %s
            WHERE  product_id = %s
            RETURNING product_id
            """,
            (body.add_qty, product_id),
        )

        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Product not found")

        row = _fetch_product(cur, product_id)

    db.commit()
    return row


@router.patch("/products/{product_id}/image", response_model=ProductOut)
def set_product_image(
    product_id: int,
    body: ProductImageAssign,
    _: dict = Depends(require("stock")),
    db=Depends(get_db),
):
    """Assign an existing or newly uploaded image URL to a product."""
    image_url = (body.image_url or "").strip() or None
    with db.cursor() as cur:
        cur.execute(
            """
            UPDATE products
            SET    image_url = %s
            WHERE  product_id = %s
            RETURNING name
            """,
            (image_url, product_id),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Product not found")

        _register_product_image(cur, row["name"], image_url, "Assigned from stock manager")
        product = _fetch_product(cur, product_id)

    db.commit()
    return product


@router.patch("/products/{product_id}/discontinue", response_model=SuccessResponse)
def discontinue_product(
    product_id: int,
    _: dict = Depends(require("stock")),
    db=Depends(get_db),
):
    """S10 — mark a product inactive (discontinued)."""
    with db.cursor() as cur:
        cur.execute(
            "UPDATE products SET is_active = 0 WHERE product_id = %s",
            (product_id,),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Product not found")

    db.commit()
    return SuccessResponse(success=True)


@router.patch("/products/{product_id}/reactivate", response_model=SuccessResponse)
def reactivate_product(
    product_id: int,
    _: dict = Depends(require("stock")),
    db=Depends(get_db),
):
    """Re-activate a previously discontinued product."""
    with db.cursor() as cur:
        cur.execute(
            "UPDATE products SET is_active = 1 WHERE product_id = %s",
            (product_id,),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Product not found")

    db.commit()
    return SuccessResponse(success=True)


# ─────────────────────────────────────────────
# Product images
# ─────────────────────────────────────────────

@router.get("/product-images", response_model=list[ProductImageOut])
def list_product_images(_: dict = Depends(require("view")), db=Depends(get_db)):
    with db.cursor() as cur:
        cur.execute(
            """
            SELECT image_id, label, image_url, source, created_at
            FROM   product_images
            ORDER  BY label, image_id
            """
        )
        return cur.fetchall()


@router.post("/product-images", response_model=ProductImageOut, status_code=201)
def upload_product_image(
    label: str = Form(..., min_length=1, max_length=150),
    file: UploadFile = File(...),
    source: str | None = Form(default=None, max_length=500),
    _: dict = Depends(require("stock")),
    db=Depends(get_db),
):
    """Upload an image and register it in the product image library."""
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail="Upload a JPG, PNG, WebP, or GIF image")

    content = file.file.read(MAX_IMAGE_BYTES + 1)
    if len(content) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=400, detail="Image file must be 5 MB or smaller")

    PRODUCT_IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    filename = _safe_filename(label, file.filename)
    suffix = Path(filename).suffix.lower()
    expected_suffix = ALLOWED_IMAGE_TYPES[file.content_type]
    if suffix == ".jpg" and expected_suffix == ".jpeg":
        expected_suffix = ".jpg"
    if suffix not in {expected_suffix, ".jpg" if expected_suffix == ".jpeg" else expected_suffix}:
        filename = f"{Path(filename).stem}{expected_suffix}"

    destination = PRODUCT_IMAGE_DIR / filename
    destination.write_bytes(content)
    image_url = f"/api/product-images/{filename}"

    with db.cursor() as cur:
        cur.execute(
            """
            INSERT INTO product_images (label, image_url, source)
            VALUES (%s, %s, %s)
            RETURNING image_id, label, image_url, source, created_at
            """,
            (label, image_url, source or "Staff upload"),
        )
        row = cur.fetchone()

    db.commit()
    return row


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
        cur.execute(
            """
            SELECT supplier_id, name, contact_name, phone, email, address
            FROM   suppliers
            ORDER  BY name
            """
        )
        return cur.fetchall()
