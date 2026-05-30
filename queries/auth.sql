-- =============================================================
-- SentinelDB - Oracle staff authentication functions
-- =============================================================

WHENEVER SQLERROR EXIT SQL.SQLCODE;

ALTER SESSION SET CONTAINER=FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA=SENTINELDB;

CREATE OR REPLACE FUNCTION fn_login(
    p_username     IN VARCHAR2,
    p_password_md5 IN VARCHAR2,
    p_ip_address   IN VARCHAR2 DEFAULT NULL
) RETURN SYS_REFCURSOR
AS
    v_user_id   users.user_id%TYPE;
    v_role_id   users.role_id%TYPE;
    v_is_active users.is_active%TYPE;
    v_token     VARCHAR2(64);
    v_expires   TIMESTAMP;
    v_result    SYS_REFCURSOR;
BEGIN
    BEGIN
        SELECT u.user_id, u.role_id, u.is_active
        INTO   v_user_id, v_role_id, v_is_active
        FROM   users u
        WHERE  u.username      = p_username
          AND  u.password_hash = p_password_md5;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            raise_application_error(-20001, 'AUTH_FAIL: invalid username or password');
    END;

    IF v_is_active <> 1 THEN
        raise_application_error(-20002, 'AUTH_FAIL: account is disabled');
    END IF;

    v_token := LOWER(RAWTOHEX(SYS_GUID()));
    v_expires := CAST(SYSTIMESTAMP AS TIMESTAMP) + INTERVAL '8' HOUR;

    UPDATE sessions
    SET    is_active = 0
    WHERE  user_id = v_user_id
      AND  is_active = 1;

    INSERT INTO sessions (user_id, token_hash, expires_at, ip_address)
    VALUES (v_user_id, v_token, v_expires, p_ip_address);

    UPDATE users
    SET    last_login = CAST(SYSTIMESTAMP AS TIMESTAMP)
    WHERE  user_id = v_user_id;

    INSERT INTO audit_logs (user_id, action, table_affected, record_id, ip_address)
    VALUES (v_user_id, 'LOGIN', 'sessions', v_user_id, p_ip_address);

    OPEN v_result FOR
        SELECT v_token AS out_token,
               v_expires AS out_expires,
               r.role_name AS out_role,
               r.can_admin AS out_can_admin,
               r.can_sales AS out_can_sales,
               r.can_stock AS out_can_stock,
               r.can_view  AS out_can_view
        FROM   roles r
        WHERE  r.role_id = v_role_id;

    RETURN v_result;
END;
/

CREATE OR REPLACE FUNCTION fn_validate_session(
    p_token_hash IN VARCHAR2
) RETURN SYS_REFCURSOR
AS
    v_result SYS_REFCURSOR;
BEGIN
    OPEN v_result FOR
        SELECT u.user_id AS out_user_id,
               u.username AS out_username,
               r.role_name AS out_role,
               r.can_admin AS out_can_admin,
               r.can_sales AS out_can_sales,
               r.can_stock AS out_can_stock,
               r.can_view  AS out_can_view
        FROM   sessions s
        JOIN   users  u ON u.user_id = s.user_id
        JOIN   roles  r ON r.role_id = u.role_id
        WHERE  s.token_hash = p_token_hash
          AND  s.is_active  = 1
          AND  s.expires_at > CAST(SYSTIMESTAMP AS TIMESTAMP)
          AND  u.is_active  = 1;

    RETURN v_result;
END;
/

CREATE OR REPLACE FUNCTION fn_logout(
    p_token_hash IN VARCHAR2
) RETURN NUMBER
AS
    v_user_id users.user_id%TYPE;
BEGIN
    BEGIN
        SELECT user_id
        INTO   v_user_id
        FROM   sessions
        WHERE  token_hash = p_token_hash
          AND  is_active = 1
        FETCH FIRST 1 ROWS ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END;

    UPDATE sessions
    SET    is_active = 0
    WHERE  token_hash = p_token_hash
      AND  is_active = 1;

    INSERT INTO audit_logs (user_id, action, table_affected)
    VALUES (v_user_id, 'LOGOUT', 'sessions');

    RETURN 1;
END;
/

CREATE OR REPLACE FUNCTION fn_cleanup_sessions
RETURN NUMBER
AS
    v_count NUMBER;
BEGIN
    UPDATE sessions
    SET    is_active = 0
    WHERE  is_active = 1
      AND  expires_at <= CAST(SYSTIMESTAMP AS TIMESTAMP);

    v_count := SQL%ROWCOUNT;

    IF v_count > 0 THEN
        INSERT INTO audit_logs (user_id, action, table_affected)
        VALUES (NULL, 'CLEANUP', 'sessions');
    END IF;

    RETURN v_count;
END;
/
