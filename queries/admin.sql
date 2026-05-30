-- =============================================================
-- SentinelDB — Admin Module Queries
-- Phase 3: audit log retrieval, system config, reports
-- =============================================================

-- ─────────────────────────────────────────────
-- AD1. Full audit log — most recent first
-- ─────────────────────────────────────────────
SELECT
    al.log_id,
    COALESCE(u.username, '(deleted)')   AS actor,
    al.action,
    al.table_affected,
    al.record_id,
    al.ip_address,
    al.timestamp
FROM  audit_logs al
LEFT JOIN users u ON u.user_id = al.user_id
ORDER BY al.timestamp DESC;


-- ─────────────────────────────────────────────
-- AD2. Audit log — filter by action type
--      Actions: LOGIN, LOGOUT, INSERT, UPDATE, DELETE, CLEANUP
-- ─────────────────────────────────────────────
SELECT
    al.log_id,
    COALESCE(u.username, '(deleted)')   AS actor,
    al.action,
    al.table_affected,
    al.record_id,
    al.timestamp
FROM  audit_logs al
LEFT JOIN users u ON u.user_id = al.user_id
WHERE al.action = 'LOGIN'        -- replace with desired action
ORDER BY al.timestamp DESC;


-- ─────────────────────────────────────────────
-- AD3. Audit log — filter by specific user
-- ─────────────────────────────────────────────
SELECT
    al.log_id,
    al.action,
    al.table_affected,
    al.record_id,
    al.ip_address,
    al.timestamp
FROM  audit_logs al
WHERE al.user_id = (SELECT user_id FROM users WHERE username = 'cashier_01')
ORDER BY al.timestamp DESC;


-- ─────────────────────────────────────────────
-- AD4. Audit log — filter by date range
-- ─────────────────────────────────────────────
SELECT
    al.log_id,
    COALESCE(u.username, '(deleted)')   AS actor,
    al.action,
    al.table_affected,
    al.timestamp
FROM  audit_logs al
LEFT JOIN users u ON u.user_id = al.user_id
WHERE al.timestamp >= '2026-05-16 00:00:00'
  AND al.timestamp <  '2026-05-17 00:00:00'
ORDER BY al.timestamp DESC;


-- ─────────────────────────────────────────────
-- AD5. Login activity report — logins per user
-- ─────────────────────────────────────────────
SELECT
    u.username,
    r.role_name,
    COUNT(al.log_id)        AS total_logins,
    MAX(al.timestamp)       AS last_login_recorded
FROM  audit_logs al
JOIN  users u ON u.user_id = al.user_id
JOIN  roles r ON r.role_id = u.role_id
WHERE al.action = 'LOGIN'
GROUP BY u.user_id, u.username, r.role_name
ORDER BY total_logins DESC;


-- ─────────────────────────────────────────────
-- AD6. System activity summary — actions per table
-- ─────────────────────────────────────────────
SELECT
    table_affected,
    action,
    COUNT(*)        AS event_count
FROM  audit_logs
WHERE table_affected IS NOT NULL
GROUP BY table_affected, action
ORDER BY table_affected, action;


-- ─────────────────────────────────────────────
-- AD7. System config — view all settings
-- ─────────────────────────────────────────────
SELECT
    sc.config_key,
    sc.config_value,
    sc.description,
    sc.updated_at,
    COALESCE(u.username, '(deleted)')   AS updated_by
FROM  system_config sc
LEFT JOIN users u ON u.user_id = sc.updated_by
ORDER BY sc.config_key;


-- ─────────────────────────────────────────────
-- AD8. System config — read a single setting
-- ─────────────────────────────────────────────
SELECT config_value
FROM   system_config
WHERE  config_key = 'session_ttl_hours';


-- ─────────────────────────────────────────────
-- AD9. System config — update a setting
-- ─────────────────────────────────────────────
UPDATE system_config
SET    config_value = '12',
       updated_at   = CURRENT_TIMESTAMP,
       updated_by   = (SELECT user_id FROM users WHERE username = 'admin_user')
WHERE  config_key   = 'session_ttl_hours';

-- Verify
SELECT config_key, config_value, updated_at FROM system_config WHERE config_key = 'session_ttl_hours';


-- ─────────────────────────────────────────────
-- AD10. Revenue report — total sales by date
-- ─────────────────────────────────────────────
SELECT
    TRUNC(o.created_at)     AS sale_date,
    COUNT(o.order_id)       AS orders_placed,
    SUM(o.total_amount)     AS gross_revenue,
    SUM(CASE WHEN o.status = 'completed' THEN o.total_amount ELSE 0 END) AS confirmed_revenue
FROM  orders o
GROUP BY TRUNC(o.created_at)
ORDER BY sale_date DESC;


-- ─────────────────────────────────────────────
-- AD11. User activity report — orders per cashier
-- ─────────────────────────────────────────────
SELECT
    u.username,
    r.role_name,
    COUNT(o.order_id)           AS orders_processed,
    SUM(o.total_amount)         AS total_value_handled,
    MAX(o.created_at)           AS last_order_at
FROM  users u
JOIN  roles r  ON r.role_id = u.role_id
LEFT JOIN orders o ON o.user_id = u.user_id
GROUP BY u.user_id, u.username, r.role_name
ORDER BY orders_processed DESC;


-- ─────────────────────────────────────────────
-- AD12. Full system report — one query summary
-- ─────────────────────────────────────────────
SELECT 'Total Users'        AS metric, TO_CHAR(COUNT(*)) AS value FROM users
UNION ALL
SELECT 'Active Users',       TO_CHAR(COUNT(*))          FROM users   WHERE is_active = 1
UNION ALL
SELECT 'Total Products',     TO_CHAR(COUNT(*))          FROM products
UNION ALL
SELECT 'Active Products',    TO_CHAR(COUNT(*))          FROM products WHERE is_active = 1
UNION ALL
SELECT 'Total Customers',    TO_CHAR(COUNT(*))          FROM customers
UNION ALL
SELECT 'Total Orders',       TO_CHAR(COUNT(*))          FROM orders
UNION ALL
SELECT 'Completed Orders',   TO_CHAR(COUNT(*))          FROM orders   WHERE status = 'completed'
UNION ALL
SELECT 'Unpaid Invoices',    TO_CHAR(COUNT(*))          FROM invoices WHERE status = 'unpaid'
UNION ALL
SELECT 'Active Sessions',    TO_CHAR(COUNT(*))          FROM sessions WHERE is_active = 1 AND expires_at > CAST(SYSTIMESTAMP AS TIMESTAMP)
UNION ALL
SELECT 'Audit Log Entries',  TO_CHAR(COUNT(*))          FROM audit_logs;
