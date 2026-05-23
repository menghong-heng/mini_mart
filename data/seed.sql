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
-- Plaintext passwords (for demo/reference only — NEVER store plaintext):
--   Admin accounts   -> Admin@1234
--   Sales accounts   -> Sales@1234
--   Cashier accounts -> Cash@1234
--   User accounts    -> User@1234
--   inactive_usr     -> Old@1234  (account disabled)
--
-- Five active accounts are provided for each role so demos do not depend on
-- one shared login session. fn_login enforces a single active session per user.

INSERT INTO users (username, password_hash, role_id, is_active) VALUES
    ('admin_user',   md5('Admin@1234'), (SELECT role_id FROM roles WHERE role_name = 'Admin'),   TRUE),
    ('admin_02',     md5('Admin@1234'), (SELECT role_id FROM roles WHERE role_name = 'Admin'),   TRUE),
    ('admin_03',     md5('Admin@1234'), (SELECT role_id FROM roles WHERE role_name = 'Admin'),   TRUE),
    ('admin_04',     md5('Admin@1234'), (SELECT role_id FROM roles WHERE role_name = 'Admin'),   TRUE),
    ('admin_05',     md5('Admin@1234'), (SELECT role_id FROM roles WHERE role_name = 'Admin'),   TRUE),

    ('sales_mgr',    md5('Sales@1234'), (SELECT role_id FROM roles WHERE role_name = 'Sales'),   TRUE),
    ('sales_02',     md5('Sales@1234'), (SELECT role_id FROM roles WHERE role_name = 'Sales'),   TRUE),
    ('sales_03',     md5('Sales@1234'), (SELECT role_id FROM roles WHERE role_name = 'Sales'),   TRUE),
    ('sales_04',     md5('Sales@1234'), (SELECT role_id FROM roles WHERE role_name = 'Sales'),   TRUE),
    ('sales_05',     md5('Sales@1234'), (SELECT role_id FROM roles WHERE role_name = 'Sales'),   TRUE),

    ('cashier_01',   md5('Cash@1234'),  (SELECT role_id FROM roles WHERE role_name = 'Cashier'), TRUE),
    ('cashier_02',   md5('Cash@1234'),  (SELECT role_id FROM roles WHERE role_name = 'Cashier'), TRUE),
    ('cashier_03',   md5('Cash@1234'),  (SELECT role_id FROM roles WHERE role_name = 'Cashier'), TRUE),
    ('cashier_04',   md5('Cash@1234'),  (SELECT role_id FROM roles WHERE role_name = 'Cashier'), TRUE),
    ('cashier_05',   md5('Cash@1234'),  (SELECT role_id FROM roles WHERE role_name = 'Cashier'), TRUE),

    ('user_01',      md5('User@1234'),  (SELECT role_id FROM roles WHERE role_name = 'User'),    TRUE),
    ('user_02',      md5('User@1234'),  (SELECT role_id FROM roles WHERE role_name = 'User'),    TRUE),
    ('user_03',      md5('User@1234'),  (SELECT role_id FROM roles WHERE role_name = 'User'),    TRUE),
    ('user_04',      md5('User@1234'),  (SELECT role_id FROM roles WHERE role_name = 'User'),    TRUE),
    ('user_05',      md5('User@1234'),  (SELECT role_id FROM roles WHERE role_name = 'User'),    TRUE),

    ('inactive_usr', md5('Old@1234'),   (SELECT role_id FROM roles WHERE role_name = 'User'),    FALSE);

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
-- 5. PRODUCT IMAGES
-- ─────────────────────────────────────────────
-- The app stores image paths in PostgreSQL and serves the seeded files from
-- frontend/public/product-images. Staff uploads are stored by the API under
-- /api/product-images and are also registered in this table.

INSERT INTO product_images (label, image_url, source) VALUES
    ('Wireless Mouse',       '/product-images/wireless-mouse.jpg',       'https://commons.wikimedia.org/wiki/File:A_wireless_computer_mouse.jpg'),
    ('Mechanical Keyboard',  '/product-images/mechanical-keyboard.jpg',  'https://commons.wikimedia.org/wiki/File:Mechanical_keyboard_example.jpg'),
    ('USB-C Hub (7-port)',   '/product-images/usb-c-hub.jpg',            'https://commons.wikimedia.org/wiki/File:USB-C_Digital_AV_Multiport_Adapter.jpeg'),
    ('Sparkling Water 6-pk', '/product-images/sparkling-water.jpg',      'https://commons.wikimedia.org/wiki/File:Sparkling-bottled-water.jpg'),
    ('Orange Juice 1L',      '/product-images/orange-juice.jpg',         'https://commons.wikimedia.org/wiki/File:Orange_juice_1_edit1.jpg'),
    ('Energy Drink 4-pk',    '/product-images/energy-drink.jpg',         'https://commons.wikimedia.org/wiki/File:Battery_Energy_Drink-can-bottle.jpg'),
    ('A4 Notebook (100pg)',  '/product-images/a4-notebook.jpg',          'https://commons.wikimedia.org/wiki/File:Cuaderno_Cervantes_A4.jpg'),
    ('Ballpoint Pens Box',   '/product-images/ballpoint-pens.jpg',       'https://commons.wikimedia.org/wiki/File:Lapicero_Parker_de_color_azul..JPG'),
    ('Classic T-Shirt',      '/product-images/classic-t-shirt.jpg',      'https://commons.wikimedia.org/wiki/File:T-SHIRTS.jpg'),
    ('Slim-Fit Jeans',       '/product-images/slim-fit-jeans.jpg',       'https://commons.wikimedia.org/wiki/File:Skinny_jeans_01.jpg');

-- ─────────────────────────────────────────────
-- 6. PRODUCTS
-- ─────────────────────────────────────────────
-- stock_qty reflects current on-hand quantity (post-sales).

INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active) VALUES
    ('Wireless Mouse',       1,  29.99, 148, 1, '/product-images/wireless-mouse.jpg',      TRUE),   -- 2 sold in order 1
    ('Mechanical Keyboard',  1,  89.99,  75, 1, '/product-images/mechanical-keyboard.jpg', TRUE),
    ('USB-C Hub (7-port)',   1,  45.00,  59, 1, '/product-images/usb-c-hub.jpg',           TRUE),   -- 1 sold in order 1
    ('Sparkling Water 6-pk', 2,   4.50, 297, 2, '/product-images/sparkling-water.jpg',     TRUE),   -- 3 sold in order 2
    ('Orange Juice 1L',      2,   3.25, 198, 2, '/product-images/orange-juice.jpg',        TRUE),   -- 2 sold in order 2
    ('Energy Drink 4-pk',    2,   8.99, 179, 2, '/product-images/energy-drink.jpg',        TRUE),   -- 1 sold in order 2
    ('A4 Notebook (100pg)',  3,   2.50, 495, 3, '/product-images/a4-notebook.jpg',         TRUE),   -- 5 sold in order 3
    ('Ballpoint Pens Box',   3,   6.75, 398, 3, '/product-images/ballpoint-pens.jpg',      TRUE),   -- 2 sold in order 3
    ('Classic T-Shirt',      4,  19.99, 120, 4, '/product-images/classic-t-shirt.jpg',     TRUE),
    ('Slim-Fit Jeans',       4,  49.99,  80, 4, '/product-images/slim-fit-jeans.jpg',      FALSE);  -- discontinued

-- ─────────────────────────────────────────────
-- 7. CUSTOMERS
-- ─────────────────────────────────────────────

INSERT INTO customers (name, phone, email, address) VALUES
    ('Sophea Chan',  '+855-12-111-222', 'sophea@example.com',  'Phnom Penh, Cambodia'),
    ('Dara Nguyen',  '+855-17-333-444', 'dara@example.com',    'Siem Reap, Cambodia'),
    ('Maly Sok',     '+855-89-555-666', 'maly@example.com',    'Kampot, Cambodia'),
    ('Rith Phal',    '+855-77-777-888', 'rith@example.com',    'Battambang, Cambodia'),
    ('Chanthy Vong', '+855-96-999-000', 'chanthy@example.com', 'Phnom Penh, Cambodia');

-- ─────────────────────────────────────────────
-- 8. ORDERS + ORDER ITEMS + INVOICES
-- ─────────────────────────────────────────────
-- Orders start with total_amount = 0 and are updated after items are inserted.
-- Staff users are referenced by username so account seed order can change.

-- Order 1: Sophea buys electronics — status: completed, invoice paid
INSERT INTO orders (customer_id, user_id, total_amount, status)
    VALUES (1, (SELECT user_id FROM users WHERE username = 'cashier_01'), 0, 'completed');

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
    VALUES (2, (SELECT user_id FROM users WHERE username = 'cashier_01'), 0, 'confirmed');

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
    VALUES (3, (SELECT user_id FROM users WHERE username = 'cashier_02'), 0, 'pending');

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (3, 7, 5, 2.50),    -- 5 × A4 Notebook       = 12.50
    (3, 8, 2, 6.75);    -- 2 × Ballpoint Pens Box = 13.50

UPDATE orders
SET total_amount = (SELECT SUM(subtotal) FROM order_items WHERE order_id = 3)
WHERE order_id = 3;

-- ─────────────────────────────────────────────
-- 9. SESSIONS (two active demo sessions)
-- ─────────────────────────────────────────────

INSERT INTO sessions (user_id, token_hash, expires_at, ip_address, is_active) VALUES
    ((SELECT user_id FROM users WHERE username = 'admin_user'), md5('admin_demo_token_seed_001'),   NOW() + INTERVAL '8 hours', '192.168.1.10', TRUE),
    ((SELECT user_id FROM users WHERE username = 'cashier_01'), md5('cashier_demo_token_seed_001'), NOW() + INTERVAL '8 hours', '192.168.1.20', TRUE);

-- ─────────────────────────────────────────────
-- 10. SYSTEM CONFIG
-- ─────────────────────────────────────────────

INSERT INTO system_config (config_key, config_value, description, updated_by) VALUES
    ('session_ttl_hours',  '8',           'Session lifetime in hours before auto-expiry',   (SELECT user_id FROM users WHERE username = 'admin_user')),
    ('max_failed_logins',  '5',           'Failed login attempts before account lock',       (SELECT user_id FROM users WHERE username = 'admin_user')),
    ('require_2fa_admin',  'false',       'Require two-factor auth for admin accounts',      (SELECT user_id FROM users WHERE username = 'admin_user')),
    ('company_name',       '67 Mini Mart', 'Display name used on invoices and reports',      (SELECT user_id FROM users WHERE username = 'admin_user'));

-- ─────────────────────────────────────────────
-- 11. AUDIT LOGS (sample historical entries)
-- ─────────────────────────────────────────────

INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address) VALUES
    ((SELECT user_id FROM users WHERE username = 'admin_user'), 'LOGIN',  'sessions', 1,    '192.168.1.10'),
    ((SELECT user_id FROM users WHERE username = 'admin_user'), 'INSERT', 'products', 1,    '192.168.1.10'),
    ((SELECT user_id FROM users WHERE username = 'admin_user'), 'INSERT', 'products', 2,    '192.168.1.10'),
    ((SELECT user_id FROM users WHERE username = 'cashier_01'), 'LOGIN',  'sessions', 2,    '192.168.1.20'),
    ((SELECT user_id FROM users WHERE username = 'cashier_01'), 'INSERT', 'orders',   1,    '192.168.1.20'),
    ((SELECT user_id FROM users WHERE username = 'cashier_01'), 'INSERT', 'orders',   2,    '192.168.1.20'),
    ((SELECT user_id FROM users WHERE username = 'user_01'),    'LOGIN',  'sessions', NULL, '192.168.1.25'),
    ((SELECT user_id FROM users WHERE username = 'cashier_02'), 'INSERT', 'orders',   3,    '192.168.1.25'),
    (NULL, 'CLEANUP','sessions',    NULL, NULL);

COMMIT;
