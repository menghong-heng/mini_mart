# SentinelDB — Demo Stack Plan (Backend + Frontend)

**Goal:** Build a working web demo on top of the existing SentinelDB PostgreSQL
schema, showing how each role experiences a different application based purely
on RBAC checks.

**Approach:** DB-centric. The FastAPI backend is a thin HTTP wrapper that
delegates authentication and permission checks to the existing PL/pgSQL
functions (`fn_login`, `fn_validate_session`, `fn_logout`,
`fn_check_permission`). All RBAC logic stays in the database — the API just
exposes it over HTTP.

---

## 1. Architecture

```
┌────────────────┐     HTTP/JSON     ┌────────────────┐    SQL    ┌──────────────┐
│  React (Vite)  │ ───────────────▶ │   FastAPI       │ ────────▶ │  PostgreSQL  │
│  Tailwind CSS  │ ◀─────────────── │   psycopg3      │ ◀──────── │  SentinelDB  │
└────────────────┘   Bearer token    └────────────────┘   fn_*     └──────────────┘
       :5173                            :8000                       :5432
```

- **Token format:** opaque session hash (the 32-char MD5 returned by
  `fn_login`). Stored client-side in `localStorage`. Sent on every request as
  `Authorization: Bearer <token>`.
- **No JWT.** Every API request that needs auth calls `fn_validate_session`
  first — the session table is the single source of truth.
- **CORS:** allow `http://localhost:5173` only.

---

## 2. Tech Stack

### Backend
| Component | Choice | Why |
|---|---|---|
| Framework | **FastAPI** | Async, auto-generated OpenAPI docs, Pydantic validation |
| DB driver | **psycopg** (v3) | Modern PostgreSQL driver; raw SQL fits the DB-centric model |
| Schemas | **Pydantic v2** | Request/response validation |
| Server | **uvicorn** | Standard FastAPI server |
| Env | `python-dotenv` | DB credentials in `.env` |

### Frontend
| Component | Choice | Why |
|---|---|---|
| Framework | **React 18 + Vite** | Fast dev server, no Next.js complexity |
| Router | **react-router-dom v6** | Protected routes |
| HTTP | **axios** | Interceptors for auth header injection |
| State | **React Context** | Auth state only — no need for Redux |
| Styling | **Tailwind CSS** | Minimal forms/tables, no component library |

---

## 3. Database — Already Done

No new schema needed. The backend uses what exists:

| What | Where | Used by |
|---|---|---|
| Tables | `schema/schema.sql` | All endpoints |
| Auth functions | `queries/auth.sql` | `/auth/*` endpoints |
| Permission function | `queries/permissions.sql` | Every protected endpoint |
| Module queries | `queries/{account,stock,sales,admin}.sql` | Used as reference for endpoint SQL |
| Seed data | `data/seed.sql` | Demo accounts |

---

## 4. Backend — FastAPI

### 4.1 Project structure

```
backend/
├── .env                          # DB_URL=postgresql://user:pw@localhost/sentineldb
├── requirements.txt
├── main.py                       # FastAPI app + route registration
├── db.py                         # psycopg connection pool
├── deps.py                       # auth/permission Depends() factories
├── schemas.py                    # Pydantic models (LoginRequest, UserOut, etc.)
└── routers/
    ├── auth.py                   # /api/auth/*
    ├── account.py                # /api/users, /api/roles, /api/sessions
    ├── stock.py                  # /api/products, /api/categories, /api/suppliers
    ├── sales.py                  # /api/orders, /api/customers, /api/invoices
    └── admin.py                  # /api/audit-logs, /api/system-config, /api/reports
```

### 4.2 Authentication workflow (DB-centric)

**Login**
```
POST /api/auth/login
body: { username, password }
─────────────────────────────────────────────────
backend:
  hash = md5(password)                        # match how seed.sql stores hashes
  row  = SELECT * FROM fn_login(username, hash, request.client.host)
  if exception → 401
  return { token: row.out_token,
           expires_at: row.out_expires,
           role: row.out_role,
           permissions: { admin, sales, stock, view } }
─────────────────────────────────────────────────
client: stores token in localStorage
```

**Authenticated request**
```
GET /api/products
Headers: Authorization: Bearer <token>
─────────────────────────────────────────────────
backend (via Depends):
  row = SELECT * FROM fn_validate_session(token)
  if no row → 401
  attach `current_user` to request state
─────────────────────────────────────────────────
backend (route handler):
  allowed = SELECT fn_check_permission(token, 'view')
  if not allowed → 403
  run actual query
```

**Logout**
```
POST /api/auth/logout
─────────────────────────────────────────────────
backend:
  SELECT fn_logout(token)
  return { success: true }
```

### 4.3 RBAC dependency

A single FastAPI dependency factory wraps `fn_check_permission`:

```python
# deps.py
def require(module: str):
    def _dep(token: str = Depends(extract_bearer),
             db = Depends(get_db)) -> dict:
        user = db.execute("SELECT * FROM fn_validate_session(%s)", (token,)).fetchone()
        if not user:
            raise HTTPException(401, "Invalid or expired session")
        ok = db.execute("SELECT fn_check_permission(%s, %s)", (token, module)).fetchone()[0]
        if not ok:
            raise HTTPException(403, f"Role '{user['out_role']}' cannot access {module}")
        return user
    return _dep
```

Used in routes as:
```python
@router.get("/audit-logs", dependencies=[Depends(require("admin"))])
def list_audit_logs(): ...

@router.post("/orders", dependencies=[Depends(require("sales"))])
def create_order(): ...
```

### 4.4 API contract

| Method | Path | Required permission | Reuses |
|---|---|---|---|
| **Auth** | | | |
| POST | `/api/auth/login` | (public) | `fn_login` |
| POST | `/api/auth/logout` | session | `fn_logout` |
| GET  | `/api/auth/me` | session | `fn_validate_session` |
| **Account (Admin)** | | | |
| GET  | `/api/users` | `admin` | account.sql A1 |
| POST | `/api/users` | `admin` | account.sql A7 |
| PATCH| `/api/users/{id}/role` | `admin` | account.sql A5 |
| PATCH| `/api/users/{id}/active` | `admin` | account.sql A6 |
| GET  | `/api/roles` | session | account.sql A10 |
| GET  | `/api/sessions` | `admin` | account.sql A8 |
| **Stock** | | | |
| GET  | `/api/products` | `view` | stock.sql S1 |
| POST | `/api/products` | `stock` | stock.sql S9 |
| PATCH| `/api/products/{id}` | `stock` | stock.sql S8 |
| GET  | `/api/products/low-stock` | `stock` | stock.sql S2 |
| GET  | `/api/categories` | `view` | (categories table) |
| GET  | `/api/suppliers` | `stock` | stock.sql S7 |
| **Sales** | | | |
| GET  | `/api/orders` | `view` | sales.sql SL1 |
| GET  | `/api/orders/{id}` | `view` | sales.sql SL2 |
| POST | `/api/orders` | `sales` | sales.sql SL3 |
| PATCH| `/api/orders/{id}/status` | `sales` | sales.sql SL4/SL5 |
| GET  | `/api/customers` | `view` | (customers table) |
| GET  | `/api/invoices` | `view` | sales.sql SL8 |
| POST | `/api/invoices` | `sales` | sales.sql SL6 |
| PATCH| `/api/invoices/{id}/pay` | `sales` | sales.sql SL7 |
| **Admin** | | | |
| GET  | `/api/audit-logs` | `admin` | admin.sql AD1 |
| GET  | `/api/system-config` | `admin` | admin.sql AD7 |
| PATCH| `/api/system-config/{key}` | `admin` | admin.sql AD9 |
| GET  | `/api/reports/summary` | `admin` | admin.sql AD12 |
| GET  | `/api/reports/revenue` | `admin` | admin.sql AD10 |

**Expected error codes**
- `401 Unauthorized` — missing/invalid/expired token
- `403 Forbidden` — token valid but role lacks permission
- `404 Not Found` — resource doesn't exist
- `422 Unprocessable Entity` — Pydantic validation failed

---

## 5. Frontend — React

### 5.1 Project structure

```
frontend/
├── package.json
├── vite.config.js
├── tailwind.config.js
├── index.html
└── src/
    ├── main.jsx
    ├── App.jsx                   # Router + AuthProvider
    ├── api/
    │   ├── client.js             # axios instance with auth interceptor
    │   └── endpoints.js          # named API call functions
    ├── auth/
    │   ├── AuthContext.jsx       # user, token, permissions
    │   └── ProtectedRoute.jsx    # redirects to /login if not authed
    ├── components/
    │   ├── Navbar.jsx            # shows links based on permissions
    │   ├── DataTable.jsx         # reusable table
    │   └── PermissionGate.jsx    # <PermissionGate module="admin">...</>
    └── pages/
        ├── Login.jsx
        ├── Dashboard.jsx          # role-specific landing page
        ├── Users.jsx              # /users     (admin only)
        ├── Products.jsx           # /products  (view+)
        ├── Orders.jsx             # /orders    (view+ to read, sales to write)
        ├── AuditLogs.jsx          # /audit     (admin only)
        └── Forbidden.jsx          # 403 page
```

### 5.2 Auth context

```jsx
// auth/AuthContext.jsx
{
  token: string | null,
  user: { user_id, username, role } | null,
  permissions: { admin, sales, stock, view },   // booleans
  login(username, password): Promise,
  logout(): Promise,
  can(module): boolean                            // shortcut
}
```

After successful login, `permissions` is populated from the `/api/auth/login`
response and used by `<PermissionGate>` and `<Navbar>` to show/hide UI.

### 5.3 Role-based UI

A single `<PermissionGate>` component drives all conditional rendering:

```jsx
<PermissionGate module="admin">
  <button onClick={deleteUser}>Delete user</button>
</PermissionGate>
```

The navbar uses the same gates:

```jsx
{can('admin') && <NavLink to="/users">Users</NavLink>}
{can('admin') && <NavLink to="/audit">Audit Logs</NavLink>}
{can('view')  && <NavLink to="/products">Products</NavLink>}
{can('view')  && <NavLink to="/orders">Orders</NavLink>}
```

Each role sees a different navbar:

| Role    | Navbar |
|---------|--------|
| Admin   | Dashboard · Users · Products · Orders · Audit Logs · Config |
| Sales   | Dashboard · Products · Orders · Customers |
| Cashier | Dashboard · Orders · Customers |
| Viewer  | Dashboard · Products · Orders (read-only) |

### 5.4 Defense-in-depth

Frontend hiding ≠ security. Even if a user manually types `/users` into the
URL or opens the page via dev tools, the backend's `Depends(require("admin"))`
returns `403`. The UI hides the option; the API enforces it.

---

## 6. Implementation Phases

Each phase is one focused chunk of work, runnable on its own.

### Phase A — Backend skeleton + auth `~2 hr`
- `backend/` folder, `requirements.txt`, `.env`, `db.py`
- `main.py` with CORS
- `routers/auth.py` — login / logout / me endpoints
- Manual test with `curl` or HTTPie

### Phase B — Backend module endpoints `~3 hr`
- Implement all routers (account, stock, sales, admin)
- Wire `require()` dependency on every protected route
- Verify all endpoints via FastAPI Swagger UI at `/docs`

### Phase C — Frontend skeleton + login `~2 hr`
- Vite + React + Tailwind init
- `AuthContext`, `ProtectedRoute`, axios interceptor
- `Login` page — form posts to `/api/auth/login`, stores token, redirects
- `Dashboard` page — shows logged-in user + permissions

### Phase D — Frontend module pages `~3 hr`
- `Products.jsx` — table from `/api/products`, conditional "Add" button
- `Orders.jsx` — list + create form
- `Users.jsx` — admin-only user management
- `AuditLogs.jsx` — admin-only log viewer
- `PermissionGate` everywhere

### Phase E — Demo polish `~1 hr`
- Toast/banner for 403 responses
- Loading states on tables
- Logout button in navbar
- Seed-account quick-login buttons on `Login` page (for demo speed)

**Total estimate: ~11 hours of focused work.**

---

## 7. Demo Script (~5 min)

1. **Open `http://localhost:5173`** — login screen with 4 quick-login buttons:
   `Admin · Sales · Cashier · Viewer`.
2. **Click "Admin"** — full navbar appears. Open Users page → show role
   reassignment. Open Audit Logs → show LOGIN event just recorded.
3. **Logout. Click "Cashier"** — navbar is shorter (no Users, no Audit). Open
   Orders → create a new order. Click on Products link → it's missing from the
   nav.
4. **Manually type `/users` into URL** — frontend doesn't redirect, but the
   table loads empty because the API returns `403`. Show the Network tab.
5. **Logout. Click "Viewer"** — only Products and Orders visible, both
   read-only (no "Add" button rendered).
6. **Final slide:** show the permission matrix from `v_role_permissions` —
   that view is the single source of truth driving the entire demo.

---

## 8. Open Questions Before Implementation

- [ ] Database connection: local PostgreSQL or Docker?
- [ ] Should the React `Login` page include the 4 quick-login buttons by
      default, or only in dev mode?
- [ ] CORS origin — confirm `http://localhost:5173`.
- [ ] Logging — log every API call to `audit_logs` (extra `INSERT` per
      request) or only sensitive ones (user changes, config changes)?
