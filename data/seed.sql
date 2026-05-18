-- =============================================================
-- SentinelDB — Seed / Test Data
-- Phase 2 Implementation: roles, users, products, customers,
--   orders, sessions, system config, and audit logs
-- =============================================================
-- Run AFTER schema.sql on a fresh database.
-- Passwords are stored as MD5 hashes for demo purposes.
-- Production must use bcrypt (pgcrypto crypt()).
-- =============================================================

BEGIN;

-- ─────────────────────────────────────────────
-- 1. ROLES
-- ─────────────────────────────────────────────

INSERT INTO roles (role_name, description, can_admin, can_sales, can_stock, can_view) VALUES
    ('Admin',   'Full system access — all modules',          TRUE,  TRUE,  TRUE,  TRUE),
    ('Sales',   'Sales processing + stock edit + view',      FALSE, TRUE,  TRUE,  TRUE),
    ('Cashier', 'Order entry + invoice processing only',     FALSE, TRUE,  FALSE, TRUE),
    ('User',    'Basic staff — read-only across modules',    FALSE, FALSE, FALSE, TRUE);

-- ─────────────────────────────────────────────
-- 2. USERS
-- ─────────────────────────────────────────────
-- Plaintext passwords (for reference only — NEVER store plaintext):
--   admin_user  → Admin@1234
--   sales_mgr   → Sales@1234
--   cashier_01  → Cash@1234
--   cashier_02  → Cash@1234
--   user_01     → User@1234
--   inactive_usr→ Old@1234  (account disabled)

INSERT INTO users (username, password_hash, role_id, is_active) VALUES
    ('admin_user',   md5('Admin@1234'), 1, TRUE),
    ('sales_mgr',    md5('Sales@1234'), 2, TRUE),
    ('cashier_01',   md5('Cash@1234'),  3, TRUE),
    ('cashier_02',   md5('Cash@1234'),  3, TRUE),
    ('user_01',      md5('User@1234'),  4, TRUE),
    ('inactive_usr', md5('Old@1234'),   4, FALSE);

-- ─────────────────────────────────────────────
-- 3. CATEGORIES
-- ─────────────────────────────────────────────

INSERT INTO categories (name, description) VALUES
    ('Electronics', 'Electronic devices and accessories'),
    ('Beverages',   'Drinks and liquid refreshments'),
    ('Stationery',  'Office and school supplies'),
    ('Clothing',    'Apparel and fashion items');

-- ─────────────────────────────────────────────
-- 4. SUPPLIERS
-- ─────────────────────────────────────────────

INSERT INTO suppliers (name, contact_name, phone, email, address) VALUES
    ('TechSource Co.',   'Alice Johnson', '+1-555-0101', 'alice@techsource.com',  '123 Tech Park, Silicon Valley, CA'),
    ('FreshDrinks Ltd.', 'Bob Martinez',  '+1-555-0202', 'bob@freshdrinks.com',   '456 Beverage Blvd, Orlando, FL'),
    ('OfficeWorld Inc.', 'Carol Lee',     '+1-555-0303', 'carol@officeworld.com', '789 Supply St, Chicago, IL'),
    ('StyleHub Fashion', 'David Kim',     '+1-555-0404', 'david@stylehub.com',    '321 Fashion Ave, New York, NY');

-- ─────────────────────────────────────────────
-- 5. PRODUCTS
-- ─────────────────────────────────────────────
-- stock_qty reflects current on-hand quantity (post-sales).

INSERT INTO products (name, category_id, price, stock_qty, supplier_id, is_active) VALUES
    ('Wireless Mouse',       1,  29.99, 148, 1, TRUE),   -- 2 sold in order 1
    ('Mechanical Keyboard',  1,  89.99,  75, 1, TRUE),
    ('USB-C Hub (7-port)',    1,  45.00,  59, 1, TRUE),   -- 1 sold in order 1
    ('Sparkling Water 6-pk', 2,   4.50, 297, 2, TRUE),   -- 3 sold in order 2
    ('Orange Juice 1L',      2,   3.25, 198, 2, TRUE),   -- 2 sold in order 2
    ('Energy Drink 4-pk',    2,   8.99, 179, 2, TRUE),   -- 1 sold in order 2
    ('A4 Notebook (100pg)',  3,   2.50, 495, 3, TRUE),   -- 5 sold in order 3
    ('Ballpoint Pens Box',   3,   6.75, 398, 3, TRUE),   -- 2 sold in order 3
    ('Classic T-Shirt',      4,  19.99, 120, 4, TRUE),
    ('Slim-Fit Jeans',       4,  49.99,  80, 4, FALSE);  -- discontinued

-- ─────────────────────────────────────────────
-- 6. CUSTOMERS
-- ─────────────────────────────────────────────

INSERT INTO customers (name, phone, email, address) VALUES
    ('Sophea Chan',  '+855-12-111-222', 'sophea@example.com',  'Phnom Penh, Cambodia'),
    ('Dara Nguyen',  '+855-17-333-444', 'dara@example.com',    'Siem Reap, Cambodia'),
    ('Maly Sok',     '+855-89-555-666', 'maly@example.com',    'Kampot, Cambodia'),
    ('Rith Phal',    '+855-77-777-888', 'rith@example.com',    'Battambang, Cambodia'),
    ('Chanthy Vong', '+855-96-999-000', 'chanthy@example.com', 'Phnom Penh, Cambodia');

-- ─────────────────────────────────────────────
-- 7. ORDERS + ORDER ITEMS + INVOICES
-- ─────────────────────────────────────────────
-- Orders start with total_amount = 0 and are updated after items are inserted.
-- user_id 3 = cashier_01, user_id 4 = cashier_02

-- Order 1: Sophea buys electronics — status: completed, invoice paid
INSERT INTO orders (customer_id, user_id, total_amount, status)
    VALUES (1, 3, 0, 'completed');

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (1, 1, 2, 29.99),   -- 2 × Wireless Mouse   = 59.98
    (1, 3, 1, 45.00);   -- 1 × USB-C Hub         = 45.00

UPDATE orders
SET total_amount = (SELECT SUM(subtotal) FROM order_items WHERE order_id = 1)
WHERE order_id = 1;

INSERT INTO invoices (order_id, due_date, paid_at, status)
    VALUES (1, CURRENT_DATE + 7, NOW(), 'paid');

-- Order 2: Dara buys beverages — status: confirmed, invoice unpaid
INSERT INTO orders (customer_id, user_id, total_amount, status)
    VALUES (2, 3, 0, 'confirmed');

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (2, 4, 3,  4.50),   -- 3 × Sparkling Water   = 13.50
    (2, 5, 2,  3.25),   -- 2 × Orange Juice       =  6.50
    (2, 6, 1,  8.99);   -- 1 × Energy Drink       =  8.99

UPDATE orders
SET total_amount = (SELECT SUM(subtotal) FROM order_items WHERE order_id = 2)
WHERE order_id = 2;

INSERT INTO invoices (order_id, due_date, status)
    VALUES (2, CURRENT_DATE + 14, 'unpaid');

-- Order 3: Maly buys stationery — status: pending, no invoice yet
INSERT INTO orders (customer_id, user_id, total_amount, status)
    VALUES (3, 4, 0, 'pending');

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (3, 7, 5, 2.50),    -- 5 × A4 Notebook       = 12.50
    (3, 8, 2, 6.75);    -- 2 × Ballpoint Pens Box = 13.50

UPDATE orders
SET total_amount = (SELECT SUM(subtotal) FROM order_items WHERE order_id = 3)
WHERE order_id = 3;

-- ─────────────────────────────────────────────
-- 8. SESSIONS (two active demo sessions)
-- ─────────────────────────────────────────────

INSERT INTO sessions (user_id, token_hash, expires_at, ip_address, is_active) VALUES
    (1, md5('admin_demo_token_seed_001'),   NOW() + INTERVAL '8 hours', '192.168.1.10', TRUE),
    (3, md5('cashier_demo_token_seed_001'), NOW() + INTERVAL '8 hours', '192.168.1.20', TRUE);

-- ─────────────────────────────────────────────
-- 9. SYSTEM CONFIG
-- ─────────────────────────────────────────────

INSERT INTO system_config (config_key, config_value, description, updated_by) VALUES
    ('session_ttl_hours',  '8',           'Session lifetime in hours before auto-expiry',   1),
    ('max_failed_logins',  '5',           'Failed login attempts before account lock',       1),
    ('require_2fa_admin',  'false',       'Require two-factor auth for admin accounts',      1),
    ('company_name',       '67mini mart', 'Display name used on invoices and reports',       1);

-- ─────────────────────────────────────────────
-- 10. AUDIT LOGS (sample historical entries)
-- ─────────────────────────────────────────────

INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address) VALUES
    (1,    'LOGIN',  'sessions',    1, '192.168.1.10'),
    (1,    'INSERT', 'products',    1, '192.168.1.10'),
    (1,    'INSERT', 'products',    2, '192.168.1.10'),
    (3,    'LOGIN',  'sessions',    2, '192.168.1.20'),
    (3,    'INSERT', 'orders',      1, '192.168.1.20'),
    (3,    'INSERT', 'orders',      2, '192.168.1.20'),
    (5,    'LOGIN',  'sessions',    NULL, '192.168.1.25'),
    (4,    'INSERT', 'orders',      3, '192.168.1.25'),
    (NULL, 'CLEANUP','sessions',    NULL, NULL);

COMMIT;
