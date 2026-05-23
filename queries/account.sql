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
WHERE u.is_active = TRUE
ORDER BY r.role_id, u.username;


-- ─────────────────────────────────────────────
-- A4. Count users per role
-- ─────────────────────────────────────────────
SELECT
    r.role_name,
    COUNT(u.user_id)                          AS total_users,
    COUNT(u.user_id) FILTER (WHERE u.is_active) AS active_users
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
SET    is_active = FALSE
WHERE  username  = 'user_01';

-- Reactivate
UPDATE users
SET    is_active = TRUE
WHERE  username  = 'user_01';


-- ─────────────────────────────────────────────
-- A7. Add a new user
-- ─────────────────────────────────────────────
INSERT INTO users (username, password_hash, role_id, is_active)
VALUES (
    'new_cashier',
    md5('NewCash@1234'),
    (SELECT role_id FROM roles WHERE role_name = 'Cashier'),
    TRUE
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
    (s.expires_at - NOW()) AS time_left
FROM  sessions s
JOIN  users u ON u.user_id = s.user_id
JOIN  roles r ON r.role_id = u.role_id
WHERE s.is_active  = TRUE
  AND s.expires_at > NOW()
ORDER BY s.created_at DESC;


-- ─────────────────────────────────────────────
-- A9. Force-expire all sessions for a user
--     (use when disabling an account mid-session)
-- ─────────────────────────────────────────────
UPDATE sessions
SET    is_active = FALSE
WHERE  user_id  = (SELECT user_id FROM users WHERE username = 'user_01')
  AND  is_active = TRUE;


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
