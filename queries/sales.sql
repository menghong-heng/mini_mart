-- =============================================================
-- SentinelDB — Sales Module Queries
-- Phase 3: order creation, order listing, invoice generation
-- =============================================================

-- ─────────────────────────────────────────────
-- SL1. List all orders with customer and cashier info
-- ─────────────────────────────────────────────
SELECT
    o.order_id,
    c.name              AS customer,
    u.username          AS processed_by,
    o.total_amount,
    o.status,
    o.created_at
FROM  orders o
LEFT JOIN customers c ON c.customer_id = o.customer_id
JOIN  users u         ON u.user_id     = o.user_id
ORDER BY o.created_at DESC;


-- ─────────────────────────────────────────────
-- SL2. View order details with all line items
-- ─────────────────────────────────────────────
SELECT
    o.order_id,
    c.name                      AS customer,
    p.name                      AS product,
    oi.quantity,
    oi.unit_price,
    oi.subtotal,
    o.total_amount,
    o.status
FROM  orders o
LEFT JOIN customers  c  ON c.customer_id  = o.customer_id
JOIN  order_items   oi  ON oi.order_id    = o.order_id
JOIN  products       p  ON p.product_id   = oi.product_id
WHERE o.order_id = 1          -- replace with target order_id
ORDER BY oi.item_id;


-- ─────────────────────────────────────────────
-- SL3. Create a new order (full transaction)
--      Customer: Rith Phal (customer_id=4)
--      Cashier:  cashier_01 (user_id=3)
--      Items:    2× Mechanical Keyboard, 3× A4 Notebook
-- ─────────────────────────────────────────────
-- SQL*Plus users can define this variable before running the transaction:
-- VARIABLE new_order_id NUMBER

INSERT INTO orders (customer_id, user_id, total_amount, status)
VALUES (4, 3, 0, 'pending')
RETURNING order_id INTO :new_order_id;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (:new_order_id, 2, 2, (SELECT price FROM products WHERE product_id = 2));

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (:new_order_id, 7, 3, (SELECT price FROM products WHERE product_id = 7));

UPDATE orders
SET total_amount = (SELECT SUM(subtotal) FROM order_items WHERE order_id = :new_order_id)
WHERE order_id = :new_order_id;

-- Reduce stock to reflect items sold
UPDATE products SET stock_qty = stock_qty - 2 WHERE product_id = 2;
UPDATE products SET stock_qty = stock_qty - 3 WHERE product_id = 7;

COMMIT;


-- ─────────────────────────────────────────────
-- SL4. Confirm an order (pending → confirmed)
-- ─────────────────────────────────────────────
UPDATE orders
SET    status     = 'confirmed',
       updated_at = CURRENT_TIMESTAMP
WHERE  order_id = 4
  AND  status   = 'pending';


-- ─────────────────────────────────────────────
-- SL5. Cancel an order
-- ─────────────────────────────────────────────
UPDATE orders
SET    status     = 'cancelled',
       updated_at = CURRENT_TIMESTAMP
WHERE  order_id = 4
  AND  status  IN ('pending', 'confirmed');


-- ─────────────────────────────────────────────
-- SL6. Generate (insert) an invoice for an order
-- ─────────────────────────────────────────────
INSERT INTO invoices (order_id, due_date, status)
VALUES (
    3,                              -- order_id without an invoice yet
    CURRENT_DATE + 14,
    'unpaid'
);


-- ─────────────────────────────────────────────
-- SL7. Mark an invoice as paid
-- ─────────────────────────────────────────────
UPDATE invoices
SET    paid_at = CURRENT_TIMESTAMP,
       status  = 'paid'
WHERE  order_id   = 3
  AND  status     = 'unpaid';


-- ─────────────────────────────────────────────
-- SL8. Invoice listing with order and customer info
-- ─────────────────────────────────────────────
SELECT
    i.invoice_id,
    o.order_id,
    c.name              AS customer,
    o.total_amount,
    i.status            AS invoice_status,
    i.issued_at,
    i.due_date,
    i.paid_at
FROM  invoices  i
JOIN  orders    o ON o.order_id    = i.order_id
LEFT JOIN customers c ON c.customer_id = o.customer_id
ORDER BY i.issued_at DESC;


-- ─────────────────────────────────────────────
-- SL9. Sales summary — total revenue by status
-- ─────────────────────────────────────────────
SELECT
    o.status,
    COUNT(*)            AS order_count,
    SUM(o.total_amount) AS total_revenue
FROM  orders o
GROUP BY o.status
ORDER BY total_revenue DESC;


-- ─────────────────────────────────────────────
-- SL10. Top-selling products (by quantity sold)
-- ─────────────────────────────────────────────
SELECT
    p.product_id,
    p.name              AS product_name,
    c.name              AS category,
    SUM(oi.quantity)    AS total_sold,
    SUM(oi.subtotal)    AS total_revenue
FROM  order_items oi
JOIN  products    p  ON p.product_id   = oi.product_id
LEFT JOIN categories c ON c.category_id = p.category_id
GROUP BY p.product_id, p.name, c.name
ORDER BY total_sold DESC;


-- ─────────────────────────────────────────────
-- SL11. Customer order history
-- ─────────────────────────────────────────────
SELECT
    o.order_id,
    o.total_amount,
    o.status,
    i.status        AS invoice_status,
    o.created_at
FROM  orders    o
LEFT JOIN invoices i ON i.order_id = o.order_id
WHERE o.customer_id = (SELECT customer_id FROM customers WHERE name = 'Sophea Chan')
ORDER BY o.created_at DESC;


-- ─────────────────────────────────────────────
-- SL12. Overdue invoices (due date passed, still unpaid)
-- ─────────────────────────────────────────────
SELECT
    i.invoice_id,
    o.order_id,
    c.name          AS customer,
    o.total_amount,
    i.due_date,
    (CURRENT_DATE - i.due_date) AS days_overdue
FROM  invoices  i
JOIN  orders    o ON o.order_id    = i.order_id
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE i.status   = 'unpaid'
  AND i.due_date < CURRENT_DATE
ORDER BY days_overdue DESC;
