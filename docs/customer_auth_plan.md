# SentinelDB — Customer Auth + Discreet Staff Login Plan

**Status:** Approved 2026-05-16
**Goal:** Add customer-facing sign-up / sign-in (User module) without exposing
staff RBAC terminology in the customer UI, and provide a config-driven Python
file for the project owner to provision staff credentials.

---

## 1. The Two-Track Concept

| Track        | Who                    | Entry point             | Sees                                    |
|--------------|------------------------|-------------------------|-----------------------------------------|
| **Customer** | Anyone, self-service   | `/` → Sign In / Sign Up | Shop, My Orders, My Profile             |
| **Staff**    | Pre-provisioned by owner | `/staff/login` (hidden) | Existing RBAC dashboards (Stock / Sales / Admin) |

Customers never see "Cashier", "Audit Logs", "Role", or any staff terminology.
Staff knows to navigate to `/staff/login` directly — no link anywhere on
customer pages.

---

## 2. Database Changes

### 2.1 `customer_accounts` (new table)

```sql
CREATE TABLE customer_accounts (
  customer_account_id  SERIAL PRIMARY KEY,
  email                VARCHAR(255) UNIQUE NOT NULL,
  password_hash        VARCHAR(64)  NOT NULL,
  customer_id          INT REFERENCES customers(customer_id) ON DELETE CASCADE,
  is_active            BOOLEAN DEFAULT TRUE,
  created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at        TIMESTAMP
);
```

### 2.2 `customer_sessions` (new table)

```sql
CREATE TABLE customer_sessions (
  session_id           SERIAL PRIMARY KEY,
  customer_account_id  INT REFERENCES customer_accounts ON DELETE CASCADE,
  token_hash           VARCHAR(64) UNIQUE NOT NULL,
  expires_at           TIMESTAMP NOT NULL,
  ip_address           VARCHAR(45),
  created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 2.3 PL/pgSQL functions — `queries/customer_auth.sql`

- `fn_customer_signup(email, password, full_name, phone)`
  → creates `customers` row + `customer_accounts` row, returns
  `(customer_account_id, token, expires_at)` (auto-logs in after signup)
- `fn_customer_login(email, password, ip)` → `(token, expires_at, customer_id, full_name)`
- `fn_customer_validate_session(token)` → customer info or null
- `fn_customer_logout(token)`

Functions mirror the existing `fn_login` / `fn_validate_session` patterns for
consistency.

---

## 3. Backend Changes

### 3.1 `backend/routers/customer_auth.py` (new)

| Method | Path                       | Auth     |
|--------|----------------------------|----------|
| POST   | `/api/customer/signup`     | public   |
| POST   | `/api/customer/login`      | public   |
| POST   | `/api/customer/logout`     | customer |
| GET    | `/api/customer/me`         | customer |

### 3.2 `backend/routers/shop.py` (new)

| Method | Path                          | Auth             |
|--------|-------------------------------|------------------|
| GET    | `/api/shop/products`          | public           |
| GET    | `/api/shop/products/{id}`     | public           |
| POST   | `/api/shop/orders`            | customer         |
| GET    | `/api/shop/orders/mine`       | customer         |
| GET    | `/api/shop/orders/{id}`       | customer (owner) |

### 3.3 `deps.py` — new dependency

```python
def get_current_customer(token = Depends(extract_bearer), db = Depends(get_db)):
    row = db.execute(
        "SELECT * FROM fn_customer_validate_session(%s)", (token,)
    ).fetchone()
    if not row:
        raise HTTPException(401, "Invalid customer session")
    return row
```

Staff `require(module)` is untouched. The two dependencies never mix.

### 3.4 `main.py` — register both tracks

```python
app.include_router(customer_auth.router, prefix="/api/customer")
app.include_router(shop.router,          prefix="/api/shop")
# existing staff routers untouched
```

---

## 4. Staff Management File — `backend/manage_staff.py`

Config-driven Python script with CLI flags. Reads `DB_URL` from `.env`.

```python
# Edit this list, then run: python manage_staff.py
STAFF = [
    {"username": "alice",   "password": "AdminPass123",   "role": "Admin",   "active": True},
    {"username": "bob",     "password": "SalesPass123",   "role": "Sales",   "active": True},
    {"username": "charlie", "password": "CashierPass123", "role": "Cashier", "active": True},
    {"username": "dora",    "password": "ViewerPass123",  "role": "Viewer",  "active": True},
]
```

**Commands**

| Command                                          | Effect                                  |
|--------------------------------------------------|-----------------------------------------|
| `python manage_staff.py`                         | Sync the STAFF list (upsert all)        |
| `python manage_staff.py --list`                  | Print current staff + roles            |
| `python manage_staff.py --reset-password alice`  | Interactive password reset             |
| `python manage_staff.py --deactivate alice`      | Set `is_active = false`                |

Password hashing uses MD5 to match the existing `seed.sql` convention so
`fn_login` continues to work unchanged.

---

## 5. Frontend Changes

### 5.1 Route reorganization

| Route              | Purpose                       | Auth     |
|--------------------|-------------------------------|----------|
| `/`                | Home / product catalog        | public   |
| `/signup`          | Customer sign up              | public   |
| `/login`           | Customer sign in              | public   |
| `/shop`            | Product browse                | public   |
| `/orders/mine`     | My orders                     | customer |
| `/account`         | My profile                    | customer |
| `/staff/login`     | Staff sign in (hidden)        | public   |
| `/staff/dashboard` | Staff landing                 | staff    |
| `/staff/users`     | (existing) Users page         | admin    |
| `/staff/products`  | (existing) Products page      | stock+   |
| `/staff/orders`    | (existing) Orders page        | sales+   |
| `/staff/audit`     | (existing) Audit page         | admin    |

### 5.2 New pages

- `pages/Signup.jsx`
- `pages/Login.jsx` (replaces current Login, becomes customer-only)
- `pages/Shop.jsx`
- `pages/MyOrders.jsx`
- `pages/StaffLogin.jsx`

### 5.3 Two auth contexts

- `CustomerAuthContext` — token stored as `localStorage.customer_token`
- `StaffAuthContext`    — token stored as `localStorage.staff_token`

The tokens are independent. A customer login does not grant staff access, and
vice versa.

---

## 6. Implementation Phases

| Phase | Scope                                                                   | Est.   |
|-------|-------------------------------------------------------------------------|--------|
| F1    | DB: `customer_accounts`, `customer_sessions`, 4 PL/pgSQL functions       | 45 min |
| F2    | Backend: `manage_staff.py` (config + CLI flags) + manual test            | 30 min |
| F3    | Backend: `customer_auth.py`, `shop.py`, `get_current_customer` dep        | 1 hr   |
| F4    | Frontend: reorganize routes under `/staff/*`, add `StaffLogin.jsx`        | 30 min |
| F5    | Frontend: `Signup`, `Login` (customer), `Shop`, `MyOrders`                | 1.5 hr |
| F6    | E2E test: signup → login → place order → admin sees it in `/staff/orders` | 30 min |

**Total: ~4.5 hours.**

---

## 7. Decisions Locked In (2026-05-16)

1. Customer credentials in a **separate** `customer_accounts` table — keeps
   staff and customer trust boundaries clean.
2. Staff login at **hidden** `/staff/login` URL — no visible link from any
   customer page.
3. Staff management via **config-driven Python file with CLI flags** —
   `STAFF = [...]` at top of `backend/manage_staff.py` + `--list`,
   `--reset-password`, `--deactivate` for one-off operations.
