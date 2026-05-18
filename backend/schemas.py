"""Pydantic request/response models for all modules."""

from datetime import date, datetime
from pydantic import BaseModel, Field


# ─────────────────────────────────────────────
# Shared
# ─────────────────────────────────────────────

class Permissions(BaseModel):
    admin: bool
    sales: bool
    stock: bool
    view: bool


class SuccessResponse(BaseModel):
    success: bool


# ─────────────────────────────────────────────
# Auth
# ─────────────────────────────────────────────

class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=1)


class LoginResponse(BaseModel):
    token: str
    expires_at: datetime
    role: str
    permissions: Permissions


class UserInfo(BaseModel):
    user_id: int
    username: str
    role: str
    permissions: Permissions


# ─────────────────────────────────────────────
# Account module
# ─────────────────────────────────────────────

class UserOut(BaseModel):
    user_id: int
    username: str
    role_name: str
    is_active: bool
    created_at: datetime
    last_login: datetime | None = None


class UserCreate(BaseModel):
    username: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=6)
    role_name: str


class RoleAssign(BaseModel):
    role_name: str


class ActiveToggle(BaseModel):
    is_active: bool


class RoleOut(BaseModel):
    role_id: int
    role_name: str
    can_admin: bool
    can_sales: bool
    can_stock: bool
    can_view: bool


class SessionOut(BaseModel):
    session_id: int
    username: str
    role_name: str
    ip_address: str | None = None
    created_at: datetime
    expires_at: datetime


# ─────────────────────────────────────────────
# Stock module
# ─────────────────────────────────────────────

class CategoryOut(BaseModel):
    category_id: int
    name: str
    description: str | None = None


class SupplierOut(BaseModel):
    supplier_id: int
    name: str
    contact_name: str | None = None
    phone: str | None = None
    email: str | None = None
    address: str | None = None


class ProductOut(BaseModel):
    product_id: int
    name: str
    category: str | None = None
    price: float
    stock_qty: int
    supplier: str | None = None
    is_active: bool


class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    category_id: int | None = None
    price: float = Field(ge=0)
    stock_qty: int = Field(default=0, ge=0)
    supplier_id: int | None = None


class ProductRestock(BaseModel):
    add_qty: int = Field(gt=0, description="Units to add to current stock")


# ─────────────────────────────────────────────
# Sales module
# ─────────────────────────────────────────────

class CustomerOut(BaseModel):
    customer_id: int
    name: str
    phone: str | None = None
    email: str | None = None
    address: str | None = None


class OrderItemCreate(BaseModel):
    product_id: int
    quantity: int = Field(gt=0)


class OrderCreate(BaseModel):
    customer_id: int | None = None
    items: list[OrderItemCreate] = Field(min_length=1)


class OrderItemOut(BaseModel):
    item_id: int
    product: str
    quantity: int
    unit_price: float
    subtotal: float


class OrderOut(BaseModel):
    order_id: int
    customer: str | None = None
    processed_by: str
    total_amount: float
    status: str
    created_at: datetime


class OrderDetail(BaseModel):
    order_id: int
    customer: str | None = None
    processed_by: str
    items: list[OrderItemOut]
    total_amount: float
    status: str
    created_at: datetime


class StatusUpdate(BaseModel):
    status: str = Field(
        pattern="^(confirmed|shipped|completed|cancelled)$",
        description="One of: confirmed, shipped, completed, cancelled",
    )


class InvoiceOut(BaseModel):
    invoice_id: int
    order_id: int
    customer: str | None = None
    total_amount: float
    status: str
    issued_at: datetime
    due_date: date | None = None
    paid_at: datetime | None = None


class InvoiceCreate(BaseModel):
    order_id: int
    due_days: int = Field(default=14, gt=0, description="Days until invoice is due")


# ─────────────────────────────────────────────
# Admin module
# ─────────────────────────────────────────────

class AuditLogOut(BaseModel):
    log_id: int
    actor: str
    action: str
    table_affected: str | None = None
    record_id: int | None = None
    ip_address: str | None = None
    timestamp: datetime


class ConfigOut(BaseModel):
    config_key: str
    config_value: str
    description: str | None = None
    updated_at: datetime
    updated_by: str | None = None


class ConfigUpdate(BaseModel):
    config_value: str = Field(min_length=1)


class SummaryRow(BaseModel):
    metric: str
    value: str


class RevenueRow(BaseModel):
    sale_date: date
    orders_placed: int
    gross_revenue: float
    confirmed_revenue: float


# ─────────────────────────────────────────────
# Dashboard
# ─────────────────────────────────────────────

class ActivityEntry(BaseModel):
    type: str  # 'signup' | 'order' | 'invoice'
    record_id: int
    label: str
    created_at: datetime


# ─────────────────────────────────────────────
# Customer auth
# ─────────────────────────────────────────────

class CustomerSignupRequest(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=6)
    full_name: str = Field(min_length=1, max_length=150)
    phone: str | None = None


class CustomerLoginRequest(BaseModel):
    email: str
    password: str = Field(min_length=1)


class CustomerLoginResponse(BaseModel):
    token: str
    expires_at: datetime
    customer_id: int
    full_name: str
    email: str
    phone: str | None = None


class CustomerInfo(BaseModel):
    customer_id: int
    email: str
    full_name: str
    phone: str | None = None


# ─────────────────────────────────────────────
# Shop (public + customer-authenticated)
# ─────────────────────────────────────────────

class ShopProductOut(BaseModel):
    product_id: int
    name: str
    category: str | None = None
    price: float
    stock_qty: int


class ShopOrderOut(BaseModel):
    order_id: int
    total_amount: float
    status: str
    created_at: datetime
    invoice_status: str


class ShopOrderItemOut(BaseModel):
    item_id: int
    product: str
    quantity: int
    unit_price: float
    subtotal: float


class ShopOrderDetail(BaseModel):
    order_id: int
    total_amount: float
    status: str
    created_at: datetime
    invoice_status: str
    items: list[ShopOrderItemOut]


class ShopOrderItemCreate(BaseModel):
    product_id: int
    quantity: int = Field(gt=0)


class ShopOrderCreate(BaseModel):
    items: list[ShopOrderItemCreate] = Field(min_length=1)


class ShopOrderCreated(BaseModel):
    order_id: int
    total_amount: float
    status: str
