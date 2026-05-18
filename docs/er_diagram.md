# SentinelDB — ER Diagram

```mermaid
erDiagram

    %% ── ACCOUNT MODULE ──────────────────────────────────────────
    roles {
        int      role_id     PK
        varchar  role_name
        text     description
        boolean  can_admin
        boolean  can_sales
        boolean  can_stock
        boolean  can_view
        timestamp created_at
    }

    users {
        int      user_id       PK
        varchar  username
        varchar  password_hash
        int      role_id       FK
        boolean  is_active
        timestamp created_at
        timestamp last_login
    }

    sessions {
        int      session_id  PK
        int      user_id     FK
        varchar  token_hash
        timestamp created_at
        timestamp expires_at
        varchar  ip_address
        boolean  is_active
    }

    %% ── STOCK MODULE ─────────────────────────────────────────────
    categories {
        int      category_id PK
        varchar  name
        text     description
        timestamp created_at
    }

    suppliers {
        int      supplier_id  PK
        varchar  name
        varchar  contact_name
        varchar  phone
        varchar  email
        text     address
        timestamp created_at
    }

    products {
        int      product_id  PK
        varchar  name
        int      category_id FK
        numeric  price
        int      stock_qty
        int      supplier_id FK
        boolean  is_active
        timestamp created_at
    }

    %% ── SALES MODULE ─────────────────────────────────────────────
    customers {
        int      customer_id PK
        varchar  name
        varchar  phone
        varchar  email
        text     address
        timestamp created_at
    }

    orders {
        int      order_id     PK
        int      customer_id  FK
        int      user_id      FK
        numeric  total_amount
        varchar  status
        timestamp created_at
        timestamp updated_at
    }

    order_items {
        int      item_id    PK
        int      order_id   FK
        int      product_id FK
        int      quantity
        numeric  unit_price
        numeric  subtotal
    }

    invoices {
        int      invoice_id PK
        int      order_id   FK
        timestamp issued_at
        date     due_date
        timestamp paid_at
        varchar  status
        text     notes
    }

    %% ── ADMIN MODULE ─────────────────────────────────────────────
    audit_logs {
        int      log_id         PK
        int      user_id        FK
        varchar  action
        varchar  table_affected
        int      record_id
        jsonb    old_value
        jsonb    new_value
        varchar  ip_address
        timestamp timestamp
    }

    system_config {
        int      config_id    PK
        varchar  config_key
        text     config_value
        text     description
        timestamp updated_at
        int      updated_by   FK
    }

    %% ── RELATIONSHIPS ────────────────────────────────────────────
    roles        ||--o{ users         : "assigned to"
    users        ||--o{ sessions      : "opens"
    users        ||--o{ orders        : "processes"
    users        ||--o{ audit_logs    : "generates"
    users        ||--o{ system_config : "last updated by"
    categories   ||--o{ products      : "groups"
    suppliers    ||--o{ products      : "supplies"
    customers    ||--o{ orders        : "places"
    orders       ||--|{ order_items   : "contains"
    products     ||--o{ order_items   : "included in"
    orders       ||--o| invoices      : "billed as"
```

---

## Foreign Key Summary

| Table | Column | References |
|---|---|---|
| `users` | `role_id` | `roles.role_id` |
| `sessions` | `user_id` | `users.user_id` |
| `products` | `category_id` | `categories.category_id` |
| `products` | `supplier_id` | `suppliers.supplier_id` |
| `orders` | `customer_id` | `customers.customer_id` |
| `orders` | `user_id` | `users.user_id` |
| `order_items` | `order_id` | `orders.order_id` |
| `order_items` | `product_id` | `products.product_id` |
| `invoices` | `order_id` | `orders.order_id` |
| `audit_logs` | `user_id` | `users.user_id` |
| `system_config` | `updated_by` | `users.user_id` |

---

## Cardinality Notes

| Relationship | Type | Meaning |
|---|---|---|
| roles → users | 1 : N | One role is held by many users |
| users → sessions | 1 : N | One user can have many active sessions |
| users → orders | 1 : N | One cashier/staff processes many orders |
| categories → products | 1 : N | One category groups many products |
| suppliers → products | 1 : N | One supplier provides many products |
| customers → orders | 1 : N | One customer places many orders |
| orders → order_items | 1 : N (mandatory) | Every order has at least one item |
| products → order_items | 1 : N | One product appears in many order lines |
| orders → invoices | 1 : 0..1 | An order generates at most one invoice |
