-- =============================================================
-- SentinelDB — Full Table Schema
-- Phase 1 Design: all tables with column types and constraints
-- =============================================================

-- ─────────────────────────────────────────────
-- ACCOUNT MODULE
-- ─────────────────────────────────────────────

CREATE TABLE roles (
    role_id     SERIAL          PRIMARY KEY,
    role_name   VARCHAR(50)     NOT NULL UNIQUE,
    description TEXT,
    can_admin   BOOLEAN         NOT NULL DEFAULT FALSE,
    can_sales   BOOLEAN         NOT NULL DEFAULT FALSE,
    can_stock   BOOLEAN         NOT NULL DEFAULT FALSE,
    can_view    BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users (
    user_id       SERIAL          PRIMARY KEY,
    username      VARCHAR(100)    NOT NULL UNIQUE,
    password_hash VARCHAR(255)    NOT NULL,
    role_id       INT             NOT NULL REFERENCES roles(role_id),
    is_active     BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login    TIMESTAMP
);

CREATE TABLE sessions (
    session_id  SERIAL          PRIMARY KEY,
    user_id     INT             NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token_hash  VARCHAR(255)    NOT NULL UNIQUE,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at  TIMESTAMP       NOT NULL,
    ip_address  VARCHAR(45),
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_session_expiry CHECK (expires_at > created_at)
);

-- ─────────────────────────────────────────────
-- STOCK MODULE
-- ─────────────────────────────────────────────

CREATE TABLE categories (
    category_id SERIAL          PRIMARY KEY,
    name        VARCHAR(100)    NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE suppliers (
    supplier_id  SERIAL          PRIMARY KEY,
    name         VARCHAR(150)    NOT NULL,
    contact_name VARCHAR(100),
    phone        VARCHAR(20),
    email        VARCHAR(150),
    address      TEXT,
    created_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
    product_id  SERIAL          PRIMARY KEY,
    name        VARCHAR(150)    NOT NULL,
    category_id INT             REFERENCES categories(category_id) ON DELETE SET NULL,
    price       NUMERIC(10,2)   NOT NULL CHECK (price >= 0),
    stock_qty   INT             NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    supplier_id INT             REFERENCES suppliers(supplier_id) ON DELETE SET NULL,
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ─────────────────────────────────────────────
-- SALES MODULE
-- ─────────────────────────────────────────────

CREATE TABLE customers (
    customer_id SERIAL          PRIMARY KEY,
    name        VARCHAR(150)    NOT NULL,
    phone       VARCHAR(20),
    email       VARCHAR(150),
    address     TEXT,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    order_id     SERIAL          PRIMARY KEY,
    customer_id  INT             REFERENCES customers(customer_id) ON DELETE SET NULL,
    user_id      INT             REFERENCES users(user_id),  -- NULL = customer self-service order; NOT NULL = staff-processed
    total_amount NUMERIC(12,2)   NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    status       VARCHAR(20)     NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'confirmed', 'shipped', 'completed', 'cancelled')),
    created_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    item_id    SERIAL          PRIMARY KEY,
    order_id   INT             NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INT             NOT NULL REFERENCES products(product_id),
    quantity   INT             NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2)   NOT NULL CHECK (unit_price >= 0),
    subtotal   NUMERIC(12,2)   GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE TABLE invoices (
    invoice_id  SERIAL          PRIMARY KEY,
    order_id    INT             NOT NULL UNIQUE REFERENCES orders(order_id),
    issued_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    due_date    DATE,
    paid_at     TIMESTAMP,
    status      VARCHAR(20)     NOT NULL DEFAULT 'unpaid'
                    CHECK (status IN ('unpaid', 'paid', 'overdue', 'cancelled')),
    notes       TEXT
);

-- ─────────────────────────────────────────────
-- ADMIN MODULE
-- ─────────────────────────────────────────────

CREATE TABLE audit_logs (
    log_id         SERIAL          PRIMARY KEY,
    user_id        INT             REFERENCES users(user_id) ON DELETE SET NULL,
    action         VARCHAR(50)     NOT NULL,
    table_affected VARCHAR(100),
    record_id      INT,
    old_value      JSONB,
    new_value      JSONB,
    ip_address     VARCHAR(45),
    timestamp      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE system_config (
    config_id    SERIAL          PRIMARY KEY,
    config_key   VARCHAR(100)    NOT NULL UNIQUE,
    config_value TEXT            NOT NULL,
    description  TEXT,
    updated_at   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by   INT             REFERENCES users(user_id) ON DELETE SET NULL
);
