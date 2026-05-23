-- =============================================================
-- SentinelDB — Authentication Flow
-- Phase 2 Implementation: login, session validation, logout
-- =============================================================
-- Functions:
--   fn_login(username, password_md5, ip)  → opens a session, returns token + role
--   fn_validate_session(token_hash)       → verifies token, returns user + role
--   fn_logout(token_hash)                 → invalidates session, returns boolean
--   fn_cleanup_sessions()                 → deactivates all expired sessions
-- =============================================================

-- ─────────────────────────────────────────────
-- fn_login
-- ─────────────────────────────────────────────
-- Flow: credential check → invalidate old sessions → open new session
--       → update last_login → audit log → return token + role info
--
-- The application must send md5(plaintext_password) as p_password_md5.
-- This matches how passwords are stored in seed.sql.

CREATE OR REPLACE FUNCTION fn_login(
    p_username     VARCHAR,
    p_password_md5 VARCHAR,
    p_ip_address   VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    out_token     VARCHAR,
    out_expires   TIMESTAMP,
    out_role      VARCHAR,
    out_can_admin BOOLEAN,
    out_can_sales BOOLEAN,
    out_can_stock BOOLEAN,
    out_can_view  BOOLEAN
) AS $$
DECLARE
    v_user_id   INT;
    v_role_id   INT;
    v_is_active BOOLEAN;
    v_token     VARCHAR;
    v_expires   TIMESTAMP;
BEGIN
    -- 1. Look up user and verify password hash
    SELECT u.user_id, u.role_id, u.is_active
    INTO   v_user_id, v_role_id, v_is_active
    FROM   users u
    WHERE  u.username      = p_username
      AND  u.password_hash = p_password_md5;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'AUTH_FAIL: invalid username or password';
    END IF;

    IF NOT v_is_active THEN
        RAISE EXCEPTION 'AUTH_FAIL: account is disabled';
    END IF;

    -- 2. Generate a unique session token (no extension required)
    v_token  := md5(random()::text || clock_timestamp()::text || p_username);
    v_expires := clock_timestamp() + INTERVAL '8 hours';

    -- 3. Invalidate any existing active sessions for this user (single-session policy)
    UPDATE sessions
    SET    is_active = FALSE
    WHERE  user_id  = v_user_id
      AND  is_active = TRUE;

    -- 4. Create the new session
    INSERT INTO sessions (user_id, token_hash, expires_at, ip_address)
    VALUES (v_user_id, v_token, v_expires, p_ip_address);

    -- 5. Record last login time
    UPDATE users
    SET    last_login = clock_timestamp()
    WHERE  user_id = v_user_id;

    -- 6. Write audit log entry
    INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address)
    VALUES (v_user_id, 'LOGIN', 'sessions', v_user_id, p_ip_address);

    -- 7. Return token + role permissions
    RETURN QUERY
    SELECT v_token, v_expires,
           r.role_name, r.can_admin, r.can_sales, r.can_stock, r.can_view
    FROM   roles r
    WHERE  r.role_id = v_role_id;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────
-- fn_validate_session
-- ─────────────────────────────────────────────
-- Checks that the token exists, is active, has not expired, and belongs to
-- an active user. Returns user + role info. Returns no rows if invalid.

CREATE OR REPLACE FUNCTION fn_validate_session(
    p_token_hash VARCHAR
)
RETURNS TABLE (
    out_user_id   INT,
    out_username  VARCHAR,
    out_role      VARCHAR,
    out_can_admin BOOLEAN,
    out_can_sales BOOLEAN,
    out_can_stock BOOLEAN,
    out_can_view  BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT u.user_id, u.username,
           r.role_name, r.can_admin, r.can_sales, r.can_stock, r.can_view
    FROM   sessions s
    JOIN   users  u ON u.user_id  = s.user_id
    JOIN   roles  r ON r.role_id  = u.role_id
    WHERE  s.token_hash = p_token_hash
      AND  s.is_active  = TRUE
      AND  s.expires_at > clock_timestamp()
      AND  u.is_active  = TRUE;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────
-- fn_logout
-- ─────────────────────────────────────────────
-- Marks the session as inactive and writes an audit log entry.
-- Returns TRUE if the session was found and deactivated, FALSE otherwise.

CREATE OR REPLACE FUNCTION fn_logout(
    p_token_hash VARCHAR
)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id INT;
BEGIN
    UPDATE sessions
    SET    is_active = FALSE
    WHERE  token_hash = p_token_hash
      AND  is_active  = TRUE
    RETURNING user_id INTO v_user_id;

    IF FOUND THEN
        INSERT INTO audit_logs (user_id, action, table_affected)
        VALUES (v_user_id, 'LOGOUT', 'sessions');
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────
-- fn_cleanup_sessions
-- ─────────────────────────────────────────────
-- Deactivates all sessions whose expiry timestamp has passed.
-- Returns the number of sessions cleaned up.
-- Schedule this to run periodically (e.g., every hour via pg_cron or app scheduler).

CREATE OR REPLACE FUNCTION fn_cleanup_sessions()
RETURNS INT AS $$
DECLARE
    v_count INT;
BEGIN
    WITH cleaned AS (
        UPDATE sessions
        SET    is_active = FALSE
        WHERE  is_active  = TRUE
          AND  expires_at <= clock_timestamp()
        RETURNING session_id
    )
    SELECT COUNT(*) INTO v_count FROM cleaned;

    IF v_count > 0 THEN
        INSERT INTO audit_logs (user_id, action, table_affected)
        VALUES (NULL, 'CLEANUP', 'sessions');
    END IF;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;


-- =============================================================
-- DEMO / TEST USAGE
-- =============================================================

-- Step 1 — Login (returns token; copy it for steps 2-4)
-- SELECT * FROM fn_login('admin_user', md5('Admin@1234'), '127.0.0.1');
-- SELECT * FROM fn_login('sales_mgr',  md5('Sales@1234'), '127.0.0.1');
-- SELECT * FROM fn_login('cashier_01', md5('Cash@1234'),  '127.0.0.1');
-- SELECT * FROM fn_login('user_01',    md5('User@1234'),  '127.0.0.1');

-- Step 2 — Validate the returned token
-- SELECT * FROM fn_validate_session('<paste token here>');

-- Step 3 — Logout
-- SELECT fn_logout('<paste token here>');

-- Step 4 — Try validating again (should return no rows)
-- SELECT * FROM fn_validate_session('<paste token here>');

-- Step 5 — Clean up expired sessions manually
-- SELECT fn_cleanup_sessions();

-- Failure cases:
-- Wrong password:
-- SELECT * FROM fn_login('admin_user', md5('wrongpassword'), '127.0.0.1');
-- Disabled account:
-- SELECT * FROM fn_login('inactive_usr', md5('Old@1234'), '127.0.0.1');
