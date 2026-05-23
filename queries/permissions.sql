-- =============================================================
-- SentinelDB — Permission Check Logic
-- Phase 2 Implementation: role-based access control per module
-- =============================================================
-- Objects created:
--   fn_check_permission(token, module) → BOOLEAN
--   v_role_permissions                 → permission matrix view
--   v_active_sessions                  → live session monitor view
-- =============================================================

-- ─────────────────────────────────────────────
-- fn_check_permission
-- ─────────────────────────────────────────────
-- Given an active session token and a module name, returns TRUE if the
-- session's role is allowed to access that module, FALSE otherwise.
--
-- Module values: 'admin' | 'sales' | 'stock' | 'view'
-- Returns FALSE for any invalid/expired token or unknown module name.

CREATE OR REPLACE FUNCTION fn_check_permission(
    p_token_hash VARCHAR,
    p_module     VARCHAR   -- 'admin' | 'sales' | 'stock' | 'view'
)
RETURNS BOOLEAN AS $$
DECLARE
    v_allowed BOOLEAN := FALSE;
BEGIN
    SELECT
        CASE lower(p_module)
            WHEN 'admin' THEN r.can_admin
            WHEN 'sales' THEN r.can_sales
            WHEN 'stock' THEN r.can_stock
            WHEN 'view'  THEN r.can_view
            ELSE FALSE
        END
    INTO v_allowed
    FROM  sessions s
    JOIN  users u ON u.user_id = s.user_id
    JOIN  roles r ON r.role_id = u.role_id
    WHERE s.token_hash = p_token_hash
      AND s.is_active  = TRUE
      AND s.expires_at > clock_timestamp()
      AND u.is_active  = TRUE;

    RETURN COALESCE(v_allowed, FALSE);
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────
-- v_role_permissions
-- ─────────────────────────────────────────────
-- Snapshot of what each role is allowed to do across all four modules.

CREATE OR REPLACE VIEW v_role_permissions AS
SELECT
    role_id,
    role_name,
    can_admin  AS admin_module,
    can_sales  AS sales_module,
    can_stock  AS stock_module,
    can_view   AS view_module
FROM  roles
ORDER BY role_id;


-- ─────────────────────────────────────────────
-- v_active_sessions
-- ─────────────────────────────────────────────
-- All currently valid (non-expired, is_active) sessions with their
-- associated username, role, and time remaining.

CREATE OR REPLACE VIEW v_active_sessions AS
SELECT
    s.session_id,
    u.username,
    r.role_name,
    s.ip_address,
    s.created_at                              AS logged_in_at,
    s.expires_at,
    (s.expires_at - clock_timestamp())        AS time_remaining
FROM  sessions s
JOIN  users u ON u.user_id = s.user_id
JOIN  roles r ON r.role_id = u.role_id
WHERE s.is_active  = TRUE
  AND s.expires_at > clock_timestamp()
  AND u.is_active  = TRUE
ORDER BY s.created_at DESC;


-- =============================================================
-- DEMO / TEST USAGE
-- =============================================================

-- First, log in to get a token (see auth.sql):
-- SELECT out_token FROM fn_login('admin_user', md5('Admin@1234'), '127.0.0.1');

-- Then test permission checks with that token:

-- Admin token — all four should return TRUE:
-- SELECT fn_check_permission('<admin_token>', 'admin');
-- SELECT fn_check_permission('<admin_token>', 'sales');
-- SELECT fn_check_permission('<admin_token>', 'stock');
-- SELECT fn_check_permission('<admin_token>', 'view');

-- Cashier token — only 'sales' and 'view' return TRUE:
-- SELECT fn_check_permission('<cashier_token>', 'admin');   -- FALSE
-- SELECT fn_check_permission('<cashier_token>', 'sales');   -- TRUE
-- SELECT fn_check_permission('<cashier_token>', 'stock');   -- FALSE
-- SELECT fn_check_permission('<cashier_token>', 'view');    -- TRUE

-- User token — only 'view' returns TRUE:
-- SELECT fn_check_permission('<user_token>', 'admin');      -- FALSE
-- SELECT fn_check_permission('<user_token>', 'sales');      -- FALSE
-- SELECT fn_check_permission('<user_token>', 'stock');      -- FALSE
-- SELECT fn_check_permission('<user_token>', 'view');       -- TRUE

-- Invalid / expired token — all return FALSE:
-- SELECT fn_check_permission('not-a-real-token', 'view');  -- FALSE

-- View the full permission matrix:
-- SELECT * FROM v_role_permissions;

-- Monitor who is logged in right now:
-- SELECT * FROM v_active_sessions;

-- =============================================================
-- EXPECTED PERMISSION MATRIX (from seed data)
-- =============================================================
--
-- role_name | admin_module | sales_module | stock_module | view_module
-- ----------+--------------+--------------+--------------+------------
-- Admin     | TRUE         | TRUE         | TRUE         | TRUE
-- Sales     | FALSE        | TRUE         | TRUE         | TRUE
-- Cashier   | FALSE        | TRUE         | FALSE        | TRUE
-- User      | FALSE        | FALSE        | FALSE        | TRUE
