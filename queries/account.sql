-- =============================================================
-- SentinelDB — Account Module Queries
-- Phase 3: user lookup, role assignment, session management
-- =============================================================

-- ─────────────────────────────────────────────
-- A1. List all users with their role
-- ─────────────────────────────────────────────
SELECT
    u.user_id,
    u.username,
    r.role_name,
    u.is_active,
    u.created_at,
    u.last_login
FROM  users u
JOIN  roles r ON r.role_id = u.role_id
ORDER BY u.user_id;


-- ─────────────────────────────────────────────
-- A2. Look up a single user by username
-- ─────────────────────────────────────────────
SELECT
    u.user_id,
    u.username,
    r.role_name,
    r.can_admin,
    r.can_sales,
    r.can_stock,
    r.can_view,
    u.is_active,
    u.last_login
FROM  users u
JOIN  roles r ON r.role_id = u.role_id
WHERE u.username = 'admin_user';   -- replace with target username


-- ─────────────────────────────────────────────
-- A3. List only active users
-- ─────────────────────────────────────────────
SELECT
    u.user_id,
    u.username,
    r.role_name,
    u.last_login
FROM  users u
JOIN  roles r ON r.role_id = u.role_id
WHERE u.is_active = 1
ORDER BY r.role_id, u.username;


-- ─────────────────────────────────────────────
-- A4. Count users per role
-- ─────────────────────────────────────────────
SELECT
    r.role_name,
    COUNT(u.user_id)                          AS total_users,
    SUM(CASE WHEN u.is_active = 1 THEN 1 ELSE 0 END) AS active_users
FROM  roles r
LEFT JOIN users u ON u.role_id = r.role_id
GROUP BY r.role_id, r.role_name
ORDER BY r.role_id;


-- ─────────────────────────────────────────────
-- A5. Reassign a user to a different role
--     (Sales → Admin as an example)
-- ─────────────────────────────────────────────
UPDATE users
SET    role_id = (SELECT role_id FROM roles WHERE role_name = 'Admin')
WHERE  username = 'sales_mgr';

-- Verify the change
SELECT u.username, r.role_name
FROM   users u JOIN roles r ON r.role_id = u.role_id
WHERE  u.username = 'sales_mgr';

-- Revert back
UPDATE users
SET    role_id = (SELECT role_id FROM roles WHERE role_name = 'Sales')
WHERE  username = 'sales_mgr';


-- ─────────────────────────────────────────────
-- A6. Deactivate a user account
-- ─────────────────────────────────────────────
UPDATE users
SET    is_active = 0
WHERE  username  = 'user_01';

-- Reactivate
UPDATE users
SET    is_active = 1
WHERE  username  = 'user_01';


-- ─────────────────────────────────────────────
-- A7. Add a new user
-- ─────────────────────────────────────────────
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES (
    'new_cashier',
    LOWER(RAWTOHEX(STANDARD_HASH('NewCash@1234', 'MD5'))),
    (SELECT role_id FROM roles WHERE role_name = 'Cashier'),
    1
);


-- ─────────────────────────────────────────────
-- A8. View all active sessions with user/role
-- ─────────────────────────────────────────────
SELECT
    s.session_id,
    u.username,
    r.role_name,
    s.ip_address,
    s.created_at  AS login_time,
    s.expires_at,
    ROUND((CAST(s.expires_at AS DATE) - SYSDATE) * 24 * 60, 2) AS minutes_left
FROM  sessions s
JOIN  users u ON u.user_id = s.user_id
JOIN  roles r ON r.role_id = u.role_id
WHERE s.is_active  = 1
  AND s.expires_at > CAST(SYSTIMESTAMP AS TIMESTAMP)
ORDER BY s.created_at DESC;


-- ─────────────────────────────────────────────
-- A9. Force-expire all sessions for a user
--     (use when disabling an account mid-session)
-- ─────────────────────────────────────────────
UPDATE sessions
SET    is_active = 0
WHERE  user_id  = (SELECT user_id FROM users WHERE username = 'user_01')
  AND  is_active = 1;


-- ─────────────────────────────────────────────
-- A10. Full role permissions reference
-- ─────────────────────────────────────────────
SELECT
    role_name,
    can_admin  AS admin_module,
    can_sales  AS sales_module,
    can_stock  AS stock_module,
    can_view   AS view_module
FROM  roles
ORDER BY role_id;
