-- =============================================================
-- SentinelDB - Oracle seed data
-- =============================================================

WHENEVER SQLERROR EXIT SQL.SQLCODE;

ALTER SESSION SET CONTAINER=FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA=SENTINELDB;

-- 1. ROLES

INSERT INTO roles (role_name, description, can_admin, can_sales, can_stock, can_view)
VALUES ('Admin', 'Full system access - all modules', 1, 1, 1, 1);
INSERT INTO roles (role_name, description, can_admin, can_sales, can_stock, can_view)
VALUES ('Sales', 'Sales processing + stock edit + view', 0, 1, 1, 1);
INSERT INTO roles (role_name, description, can_admin, can_sales, can_stock, can_view)
VALUES ('Cashier', 'Order entry + invoice processing only', 0, 1, 0, 1);
INSERT INTO roles (role_name, description, can_admin, can_sales, can_stock, can_view)
VALUES ('User', 'Basic staff - read-only across modules', 0, 0, 0, 1);

-- 2. USERS

INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('admin_user', LOWER(RAWTOHEX(STANDARD_HASH('Admin@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Admin'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('admin_02', LOWER(RAWTOHEX(STANDARD_HASH('Admin@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Admin'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('admin_03', LOWER(RAWTOHEX(STANDARD_HASH('Admin@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Admin'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('admin_04', LOWER(RAWTOHEX(STANDARD_HASH('Admin@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Admin'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('admin_05', LOWER(RAWTOHEX(STANDARD_HASH('Admin@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Admin'), 1);

INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('sales_mgr', LOWER(RAWTOHEX(STANDARD_HASH('Sales@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Sales'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('sales_02', LOWER(RAWTOHEX(STANDARD_HASH('Sales@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Sales'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('sales_03', LOWER(RAWTOHEX(STANDARD_HASH('Sales@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Sales'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('sales_04', LOWER(RAWTOHEX(STANDARD_HASH('Sales@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Sales'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('sales_05', LOWER(RAWTOHEX(STANDARD_HASH('Sales@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Sales'), 1);

INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('cashier_01', LOWER(RAWTOHEX(STANDARD_HASH('Cash@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Cashier'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('cashier_02', LOWER(RAWTOHEX(STANDARD_HASH('Cash@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Cashier'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('cashier_03', LOWER(RAWTOHEX(STANDARD_HASH('Cash@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Cashier'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('cashier_04', LOWER(RAWTOHEX(STANDARD_HASH('Cash@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Cashier'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('cashier_05', LOWER(RAWTOHEX(STANDARD_HASH('Cash@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'Cashier'), 1);

INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('user_01', LOWER(RAWTOHEX(STANDARD_HASH('User@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'User'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('user_02', LOWER(RAWTOHEX(STANDARD_HASH('User@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'User'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('user_03', LOWER(RAWTOHEX(STANDARD_HASH('User@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'User'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('user_04', LOWER(RAWTOHEX(STANDARD_HASH('User@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'User'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('user_05', LOWER(RAWTOHEX(STANDARD_HASH('User@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'User'), 1);
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES ('inactive_usr', LOWER(RAWTOHEX(STANDARD_HASH('Old@1234', 'MD5'))), (SELECT role_id FROM roles WHERE role_name = 'User'), 0);

-- 3. CATEGORIES

INSERT INTO categories (name, description) VALUES ('Electronics', 'Electronic devices and accessories');
INSERT INTO categories (name, description) VALUES ('Beverages', 'Drinks and liquid refreshments');
INSERT INTO categories (name, description) VALUES ('Stationery', 'Office and school supplies');
INSERT INTO categories (name, description) VALUES ('Clothing', 'Apparel and fashion items');

-- 4. SUPPLIERS

INSERT INTO suppliers (name, contact_name, phone, email, address)
VALUES ('TechSource Co.', 'Alice Johnson', '+1-555-0101', 'alice@techsource.com', '123 Tech Park, Silicon Valley, CA');
INSERT INTO suppliers (name, contact_name, phone, email, address)
VALUES ('FreshDrinks Ltd.', 'Bob Martinez', '+1-555-0202', 'bob@freshdrinks.com', '456 Beverage Blvd, Orlando, FL');
INSERT INTO suppliers (name, contact_name, phone, email, address)
VALUES ('OfficeWorld Inc.', 'Carol Lee', '+1-555-0303', 'carol@officeworld.com', '789 Supply St, Chicago, IL');
INSERT INTO suppliers (name, contact_name, phone, email, address)
VALUES ('StyleHub Fashion', 'David Kim', '+1-555-0404', 'david@stylehub.com', '321 Fashion Ave, New York, NY');

-- 5. PRODUCT IMAGES

INSERT INTO product_images (label, image_url, source)
VALUES ('Wireless Mouse', '/product-images/wireless-mouse.jpg', 'https://commons.wikimedia.org/wiki/File:A_wireless_computer_mouse.jpg');
INSERT INTO product_images (label, image_url, source)
VALUES ('Mechanical Keyboard', '/product-images/mechanical-keyboard.jpg', 'https://commons.wikimedia.org/wiki/File:Mechanical_keyboard_example.jpg');
INSERT INTO product_images (label, image_url, source)
VALUES ('USB-C Hub (7-port)', '/product-images/usb-c-hub.jpg', 'https://commons.wikimedia.org/wiki/File:USB-C_Digital_AV_Multiport_Adapter.jpeg');
INSERT INTO product_images (label, image_url, source)
VALUES ('Sparkling Water 6-pk', '/product-images/sparkling-water.jpg', 'https://commons.wikimedia.org/wiki/File:Sparkling-bottled-water.jpg');
INSERT INTO product_images (label, image_url, source)
VALUES ('Orange Juice 1L', '/product-images/orange-juice.jpg', 'https://commons.wikimedia.org/wiki/File:Orange_juice_1_edit1.jpg');
INSERT INTO product_images (label, image_url, source)
VALUES ('Energy Drink 4-pk', '/product-images/energy-drink.jpg', 'https://commons.wikimedia.org/wiki/File:Battery_Energy_Drink-can-bottle.jpg');
INSERT INTO product_images (label, image_url, source)
VALUES ('A4 Notebook (100pg)', '/product-images/a4-notebook.jpg', 'https://commons.wikimedia.org/wiki/File:Cuaderno_Cervantes_A4.jpg');
INSERT INTO product_images (label, image_url, source)
VALUES ('Ballpoint Pens Box', '/product-images/ballpoint-pens.jpg', 'https://commons.wikimedia.org/wiki/File:Lapicero_Parker_de_color_azul..JPG');
INSERT INTO product_images (label, image_url, source)
VALUES ('Classic T-Shirt', '/product-images/classic-t-shirt.jpg', 'https://commons.wikimedia.org/wiki/File:T-SHIRTS.jpg');
INSERT INTO product_images (label, image_url, source)
VALUES ('Slim-Fit Jeans', '/product-images/slim-fit-jeans.jpg', 'https://commons.wikimedia.org/wiki/File:Skinny_jeans_01.jpg');

-- 6. PRODUCTS

INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active)
VALUES ('Wireless Mouse', 1, 29.99, 148, 1, '/product-images/wireless-mouse.jpg', 1);
INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active)
VALUES ('Mechanical Keyboard', 1, 89.99, 75, 1, '/product-images/mechanical-keyboard.jpg', 1);
INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active)
VALUES ('USB-C Hub (7-port)', 1, 45.00, 59, 1, '/product-images/usb-c-hub.jpg', 1);
INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active)
VALUES ('Sparkling Water 6-pk', 2, 4.50, 297, 2, '/product-images/sparkling-water.jpg', 1);
INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active)
VALUES ('Orange Juice 1L', 2, 3.25, 198, 2, '/product-images/orange-juice.jpg', 1);
INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active)
VALUES ('Energy Drink 4-pk', 2, 8.99, 179, 2, '/product-images/energy-drink.jpg', 1);
INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active)
VALUES ('A4 Notebook (100pg)', 3, 2.50, 495, 3, '/product-images/a4-notebook.jpg', 1);
INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active)
VALUES ('Ballpoint Pens Box', 3, 6.75, 398, 3, '/product-images/ballpoint-pens.jpg', 1);
INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active)
VALUES ('Classic T-Shirt', 4, 19.99, 120, 4, '/product-images/classic-t-shirt.jpg', 1);
INSERT INTO products (name, category_id, price, stock_qty, supplier_id, image_url, is_active)
VALUES ('Slim-Fit Jeans', 4, 49.99, 80, 4, '/product-images/slim-fit-jeans.jpg', 0);

-- 7. CUSTOMERS

INSERT INTO customers (name, phone, email, address)
VALUES ('Sophea Chan', '+855-12-111-222', 'sophea@example.com', 'Phnom Penh, Cambodia');
INSERT INTO customers (name, phone, email, address)
VALUES ('Dara Nguyen', '+855-17-333-444', 'dara@example.com', 'Siem Reap, Cambodia');
INSERT INTO customers (name, phone, email, address)
VALUES ('Maly Sok', '+855-89-555-666', 'maly@example.com', 'Kampot, Cambodia');
INSERT INTO customers (name, phone, email, address)
VALUES ('Rith Phal', '+855-77-777-888', 'rith@example.com', 'Battambang, Cambodia');
INSERT INTO customers (name, phone, email, address)
VALUES ('Chanthy Vong', '+855-96-999-000', 'chanthy@example.com', 'Phnom Penh, Cambodia');

-- 8. ORDERS + ORDER ITEMS + INVOICES

INSERT INTO orders (customer_id, user_id, total_amount, status)
VALUES (1, (SELECT user_id FROM users WHERE username = 'cashier_01'), 0, 'completed');

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (1, 1, 2, 29.99);
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (1, 3, 1, 45.00);

UPDATE orders
SET total_amount = (SELECT SUM(subtotal) FROM order_items WHERE order_id = 1)
WHERE order_id = 1;

INSERT INTO invoices (order_id, due_date, paid_at, status)
VALUES (1, TRUNC(CURRENT_DATE) + 7, CURRENT_TIMESTAMP, 'paid');

INSERT INTO orders (customer_id, user_id, total_amount, status)
VALUES (2, (SELECT user_id FROM users WHERE username = 'cashier_01'), 0, 'confirmed');

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (2, 4, 3, 4.50);
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (2, 5, 2, 3.25);
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (2, 6, 1, 8.99);

UPDATE orders
SET total_amount = (SELECT SUM(subtotal) FROM order_items WHERE order_id = 2)
WHERE order_id = 2;

INSERT INTO invoices (order_id, due_date, status)
VALUES (2, TRUNC(CURRENT_DATE) + 14, 'unpaid');

INSERT INTO orders (customer_id, user_id, total_amount, status)
VALUES (3, (SELECT user_id FROM users WHERE username = 'cashier_02'), 0, 'pending');

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (3, 7, 5, 2.50);
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (3, 8, 2, 6.75);

UPDATE orders
SET total_amount = (SELECT SUM(subtotal) FROM order_items WHERE order_id = 3)
WHERE order_id = 3;

-- 9. SESSIONS

INSERT INTO sessions (user_id, token_hash, expires_at, ip_address, is_active)
VALUES (
    (SELECT user_id FROM users WHERE username = 'admin_user'),
    LOWER(RAWTOHEX(STANDARD_HASH('admin_demo_token_seed_001', 'MD5'))),
    CURRENT_TIMESTAMP + INTERVAL '8' HOUR,
    '192.168.1.10',
    1
);

INSERT INTO sessions (user_id, token_hash, expires_at, ip_address, is_active)
VALUES (
    (SELECT user_id FROM users WHERE username = 'cashier_01'),
    LOWER(RAWTOHEX(STANDARD_HASH('cashier_demo_token_seed_001', 'MD5'))),
    CURRENT_TIMESTAMP + INTERVAL '8' HOUR,
    '192.168.1.20',
    1
);

-- 10. SYSTEM CONFIG

INSERT INTO system_config (config_key, config_value, description, updated_by)
VALUES ('session_ttl_hours', '8', 'Session lifetime in hours before auto-expiry', (SELECT user_id FROM users WHERE username = 'admin_user'));
INSERT INTO system_config (config_key, config_value, description, updated_by)
VALUES ('max_failed_logins', '5', 'Failed login attempts before account lock', (SELECT user_id FROM users WHERE username = 'admin_user'));
INSERT INTO system_config (config_key, config_value, description, updated_by)
VALUES ('require_2fa_admin', 'false', 'Require two-factor auth for admin accounts', (SELECT user_id FROM users WHERE username = 'admin_user'));
INSERT INTO system_config (config_key, config_value, description, updated_by)
VALUES ('company_name', '67 Mini Mart', 'Display name used on invoices and reports', (SELECT user_id FROM users WHERE username = 'admin_user'));

-- 11. AUDIT LOGS

INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address)
VALUES ((SELECT user_id FROM users WHERE username = 'admin_user'), 'LOGIN', 'sessions', 1, '192.168.1.10');
INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address)
VALUES ((SELECT user_id FROM users WHERE username = 'admin_user'), 'INSERT', 'products', 1, '192.168.1.10');
INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address)
VALUES ((SELECT user_id FROM users WHERE username = 'admin_user'), 'INSERT', 'products', 2, '192.168.1.10');
INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address)
VALUES ((SELECT user_id FROM users WHERE username = 'cashier_01'), 'LOGIN', 'sessions', 2, '192.168.1.20');
INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address)
VALUES ((SELECT user_id FROM users WHERE username = 'cashier_01'), 'INSERT', 'orders', 1, '192.168.1.20');
INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address)
VALUES ((SELECT user_id FROM users WHERE username = 'cashier_01'), 'INSERT', 'orders', 2, '192.168.1.20');
INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address)
VALUES ((SELECT user_id FROM users WHERE username = 'user_01'), 'LOGIN', 'sessions', NULL, '192.168.1.25');
INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address)
VALUES ((SELECT user_id FROM users WHERE username = 'cashier_02'), 'INSERT', 'orders', 3, '192.168.1.25');
INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address)
VALUES (NULL, 'CLEANUP', 'sessions', NULL, NULL);

COMMIT;
