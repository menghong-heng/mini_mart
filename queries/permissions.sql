-- =============================================================
-- SentinelDB - Oracle permission check logic
-- =============================================================

WHENEVER SQLERROR EXIT SQL.SQLCODE;

ALTER SESSION SET CONTAINER=FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA=SENTINELDB;

CREATE OR REPLACE FUNCTION fn_check_permission(
    p_token_hash IN VARCHAR2,
    p_module     IN VARCHAR2
) RETURN NUMBER
AS
    v_allowed NUMBER(1) := 0;
BEGIN
    BEGIN
        SELECT CASE LOWER(p_module)
                   WHEN 'admin' THEN r.can_admin
                   WHEN 'sales' THEN r.can_sales
                   WHEN 'stock' THEN r.can_stock
                   WHEN 'view'  THEN r.can_view
                   ELSE 0
               END
        INTO   v_allowed
        FROM   sessions s
        JOIN   users u ON u.user_id = s.user_id
        JOIN   roles r ON r.role_id = u.role_id
        WHERE  s.token_hash = p_token_hash
          AND  s.is_active  = 1
          AND  s.expires_at > CAST(SYSTIMESTAMP AS TIMESTAMP)
          AND  u.is_active  = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END;

    RETURN NVL(v_allowed, 0);
END;
/

CREATE OR REPLACE VIEW v_role_permissions AS
SELECT
    role_id,
    role_name,
    can_admin AS admin_module,
    can_sales AS sales_module,
    can_stock AS stock_module,
    can_view  AS view_module
FROM roles;

CREATE OR REPLACE VIEW v_active_sessions AS
SELECT
    s.session_id,
    u.username,
    r.role_name,
    s.ip_address,
    s.created_at AS logged_in_at,
    s.expires_at,
    ROUND((CAST(s.expires_at AS DATE) - SYSDATE) * 24 * 60, 2) AS minutes_remaining
FROM  sessions s
JOIN  users u ON u.user_id = s.user_id
JOIN  roles r ON r.role_id = u.role_id
WHERE s.is_active  = 1
  AND s.expires_at > CAST(SYSTIMESTAMP AS TIMESTAMP)
  AND u.is_active  = 1;
