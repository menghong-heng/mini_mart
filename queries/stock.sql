-- =============================================================
-- SentinelDB — Stock Module Queries
-- Phase 3: inventory check, product listing, suppliers
-- =============================================================

-- ─────────────────────────────────────────────
-- S1. Full product listing (active products only)
-- ─────────────────────────────────────────────
SELECT
    p.product_id,
    p.name                          AS product_name,
    c.name                          AS category,
    p.price,
    p.stock_qty,
    s.name                          AS supplier
FROM  products p
LEFT JOIN categories c ON c.category_id = p.category_id
LEFT JOIN suppliers  s ON s.supplier_id  = p.supplier_id
WHERE p.is_active = 1
ORDER BY c.name, p.name;


-- ─────────────────────────────────────────────
-- S2. Inventory check — low stock alert (qty < 100)
-- ─────────────────────────────────────────────
SELECT
    p.product_id,
    p.name          AS product_name,
    c.name          AS category,
    p.stock_qty,
    s.name          AS supplier,
    s.phone         AS supplier_phone
FROM  products p
LEFT JOIN categories c ON c.category_id = p.category_id
LEFT JOIN suppliers  s ON s.supplier_id  = p.supplier_id
WHERE p.is_active = 1
  AND p.stock_qty < 100
ORDER BY p.stock_qty ASC;


-- ─────────────────────────────────────────────
-- S3. Product listing grouped by category
-- ─────────────────────────────────────────────
SELECT
    c.name          AS category,
    COUNT(p.product_id)                          AS total_products,
    SUM(CASE WHEN p.is_active = 1 THEN 1 ELSE 0 END) AS active_products,
    SUM(CASE WHEN p.is_active = 1 THEN p.stock_qty ELSE 0 END) AS total_stock_units,
    ROUND(AVG(CASE WHEN p.is_active = 1 THEN p.price END), 2) AS avg_price
FROM  categories c
LEFT JOIN products p ON p.category_id = c.category_id
GROUP BY c.category_id, c.name
ORDER BY c.name;


-- ─────────────────────────────────────────────
-- S4. Search product by name (partial match)
-- ─────────────────────────────────────────────
SELECT
    p.product_id,
    p.name          AS product_name,
    c.name          AS category,
    p.price,
    p.stock_qty,
    p.is_active
FROM  products p
LEFT JOIN categories c ON c.category_id = p.category_id
WHERE LOWER(p.name) LIKE '%mouse%'    -- replace search term
ORDER BY p.name;


-- ─────────────────────────────────────────────
-- S5. Products supplied by a specific supplier
-- ─────────────────────────────────────────────
SELECT
    p.product_id,
    p.name          AS product_name,
    c.name          AS category,
    p.price,
    p.stock_qty,
    p.is_active
FROM  products p
LEFT JOIN categories c ON c.category_id = p.category_id
WHERE p.supplier_id = (SELECT supplier_id FROM suppliers WHERE name = 'TechSource Co.')
ORDER BY p.name;


-- ─────────────────────────────────────────────
-- S6. Stock value report — total value per category
--     (value = price × stock_qty)
-- ─────────────────────────────────────────────
SELECT
    c.name                              AS category,
    SUM(p.price * p.stock_qty)          AS stock_value,
    SUM(p.stock_qty)                    AS total_units
FROM  products p
JOIN  categories c ON c.category_id = p.category_id
WHERE p.is_active = 1
GROUP BY c.category_id, c.name
ORDER BY stock_value DESC;


-- ─────────────────────────────────────────────
-- S7. Supplier contact list
-- ─────────────────────────────────────────────
SELECT
    supplier_id,
    name,
    contact_name,
    phone,
    email,
    address
FROM  suppliers
ORDER BY name;


-- ─────────────────────────────────────────────
-- S8. Restock a product (increase stock_qty)
-- ─────────────────────────────────────────────
UPDATE products
SET    stock_qty = stock_qty + 50
WHERE  name = 'Wireless Mouse';

-- Verify
SELECT name, stock_qty FROM products WHERE name = 'Wireless Mouse';


-- ─────────────────────────────────────────────
-- S9. Add a new product
-- ─────────────────────────────────────────────
INSERT INTO products (name, category_id, price, stock_qty, supplier_id, is_active)
VALUES (
    'Laptop Stand',
    (SELECT category_id FROM categories WHERE name = 'Electronics'),
    35.00,
    40,
    (SELECT supplier_id FROM suppliers WHERE name = 'TechSource Co.'),
    1
);


-- ─────────────────────────────────────────────
-- S10. Discontinue (deactivate) a product
-- ─────────────────────────────────────────────
UPDATE products
SET    is_active = 0
WHERE  name = 'Slim-Fit Jeans';

-- Verify: list all inactive products
SELECT product_id, name, is_active
FROM   products
WHERE  is_active = 0;
