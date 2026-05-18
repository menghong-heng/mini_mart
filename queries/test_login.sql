-- =============================================================
-- SentinelDB — Login Test Script
-- Phase 2: End-to-end test of the full authentication flow
-- =============================================================
-- Prerequisites (run in this order on a fresh database):
--   \i schema/schema.sql
--   \i data/seed.sql
--   \i queries/auth.sql
--   \i queries/permissions.sql
--   \i queries/test_login.sql   ← this file
-- =============================================================

DO $$
DECLARE
    v_token     VARCHAR;
    v_expires   TIMESTAMP;
    v_role      VARCHAR;
    v_can_admin BOOLEAN;
    v_can_sales BOOLEAN;
    v_can_stock BOOLEAN;
    v_can_view  BOOLEAN;
    v_valid     INT;
    v_result    BOOLEAN;
BEGIN

-- ─────────────────────────────────────────────
-- TEST 1: Admin login → full permission check → logout
-- ─────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════';
RAISE NOTICE 'TEST 1 — Admin login';
RAISE NOTICE '══════════════════════════════════════════════';

SELECT out_token, out_expires, out_role,
       out_can_admin, out_can_sales, out_can_stock, out_can_view
INTO   v_token, v_expires, v_role,
       v_can_admin, v_can_sales, v_can_stock, v_can_view
FROM   fn_login('admin_user', md5('Admin@1234'), '127.0.0.1');

RAISE NOTICE 'Token    : %', v_token;
RAISE NOTICE 'Expires  : %', v_expires;
RAISE NOTICE 'Role     : %  (expect: Admin)', v_role;
RAISE NOTICE 'can_admin: %  (expect: true)',  v_can_admin;
RAISE NOTICE 'can_sales: %  (expect: true)',  v_can_sales;
RAISE NOTICE 'can_stock: %  (expect: true)',  v_can_stock;
RAISE NOTICE 'can_view : %  (expect: true)',  v_can_view;

RAISE NOTICE '--- fn_validate_session ---';
SELECT COUNT(*) INTO v_valid FROM fn_validate_session(v_token);
RAISE NOTICE 'Row count (expect 1): %', v_valid;

RAISE NOTICE '--- fn_check_permission ---';
SELECT fn_check_permission(v_token, 'admin') INTO v_result;
RAISE NOTICE 'admin module (expect true ): %', v_result;
SELECT fn_check_permission(v_token, 'sales') INTO v_result;
RAISE NOTICE 'sales module (expect true ): %', v_result;
SELECT fn_check_permission(v_token, 'stock') INTO v_result;
RAISE NOTICE 'stock module (expect true ): %', v_result;
SELECT fn_check_permission(v_token, 'view')  INTO v_result;
RAISE NOTICE 'view  module (expect true ): %', v_result;

RAISE NOTICE '--- fn_logout ---';
SELECT fn_logout(v_token) INTO v_result;
RAISE NOTICE 'Logout returned (expect true): %', v_result;

RAISE NOTICE '--- validate after logout ---';
SELECT COUNT(*) INTO v_valid FROM fn_validate_session(v_token);
RAISE NOTICE 'Row count after logout (expect 0): %', v_valid;


-- ─────────────────────────────────────────────
-- TEST 2: Sales login
-- ─────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════';
RAISE NOTICE 'TEST 2 — Sales login';
RAISE NOTICE '══════════════════════════════════════════════';

SELECT out_token, out_role,
       out_can_admin, out_can_sales, out_can_stock, out_can_view
INTO   v_token, v_role,
       v_can_admin, v_can_sales, v_can_stock, v_can_view
FROM   fn_login('sales_mgr', md5('Sales@1234'), '127.0.0.2');

RAISE NOTICE 'Role     : %  (expect: Sales)',  v_role;
RAISE NOTICE 'can_admin: %  (expect: false)', v_can_admin;
RAISE NOTICE 'can_sales: %  (expect: true)',  v_can_sales;
RAISE NOTICE 'can_stock: %  (expect: true)',  v_can_stock;
RAISE NOTICE 'can_view : %  (expect: true)',  v_can_view;

SELECT fn_logout(v_token) INTO v_result;


-- ─────────────────────────────────────────────
-- TEST 3: Cashier login — limited permissions
-- ─────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════';
RAISE NOTICE 'TEST 3 — Cashier login';
RAISE NOTICE '══════════════════════════════════════════════';

SELECT out_token, out_role,
       out_can_admin, out_can_sales, out_can_stock, out_can_view
INTO   v_token, v_role,
       v_can_admin, v_can_sales, v_can_stock, v_can_view
FROM   fn_login('cashier_01', md5('Cash@1234'), '127.0.0.3');

RAISE NOTICE 'Role     : %  (expect: Cashier)', v_role;
RAISE NOTICE 'can_admin: %  (expect: false)', v_can_admin;
RAISE NOTICE 'can_sales: %  (expect: true)',  v_can_sales;
RAISE NOTICE 'can_stock: %  (expect: false)', v_can_stock;
RAISE NOTICE 'can_view : %  (expect: true)',  v_can_view;

SELECT fn_check_permission(v_token, 'admin') INTO v_result;
RAISE NOTICE 'permission admin (expect false): %', v_result;
SELECT fn_check_permission(v_token, 'sales') INTO v_result;
RAISE NOTICE 'permission sales (expect true ): %', v_result;
SELECT fn_check_permission(v_token, 'stock') INTO v_result;
RAISE NOTICE 'permission stock (expect false): %', v_result;

SELECT fn_logout(v_token) INTO v_result;


-- ─────────────────────────────────────────────
-- TEST 4: Viewer login — read-only
-- ─────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════';
RAISE NOTICE 'TEST 4 — Viewer login';
RAISE NOTICE '══════════════════════════════════════════════';

SELECT out_token, out_role,
       out_can_admin, out_can_sales, out_can_stock, out_can_view
INTO   v_token, v_role,
       v_can_admin, v_can_sales, v_can_stock, v_can_view
FROM   fn_login('viewer_01', md5('View@1234'), '127.0.0.4');

RAISE NOTICE 'Role     : %  (expect: Viewer)', v_role;
RAISE NOTICE 'can_admin: %  (expect: false)', v_can_admin;
RAISE NOTICE 'can_sales: %  (expect: false)', v_can_sales;
RAISE NOTICE 'can_stock: %  (expect: false)', v_can_stock;
RAISE NOTICE 'can_view : %  (expect: true)',  v_can_view;

SELECT fn_logout(v_token) INTO v_result;


-- ─────────────────────────────────────────────
-- TEST 5: Wrong password (should raise AUTH_FAIL)
-- ─────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════';
RAISE NOTICE 'TEST 5 — Wrong password (expect AUTH_FAIL)';
RAISE NOTICE '══════════════════════════════════════════════';

BEGIN
    SELECT out_token INTO v_token
    FROM   fn_login('admin_user', md5('wrongpassword'), '127.0.0.1');
    RAISE NOTICE 'ERROR: login should have failed but did not!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught (expected): %', SQLERRM;
END;


-- ─────────────────────────────────────────────
-- TEST 6: Disabled account (should raise AUTH_FAIL)
-- ─────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════';
RAISE NOTICE 'TEST 6 — Disabled account (expect AUTH_FAIL)';
RAISE NOTICE '══════════════════════════════════════════════';

BEGIN
    SELECT out_token INTO v_token
    FROM   fn_login('inactive_usr', md5('Old@1234'), '127.0.0.1');
    RAISE NOTICE 'ERROR: login should have failed but did not!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught (expected): %', SQLERRM;
END;


-- ─────────────────────────────────────────────
-- TEST 7: Invalid token permission check
-- ─────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════';
RAISE NOTICE 'TEST 7 — Invalid token → permission check';
RAISE NOTICE '══════════════════════════════════════════════';

SELECT fn_check_permission('not-a-real-token', 'view') INTO v_result;
RAISE NOTICE 'Permission on fake token (expect false): %', v_result;

SELECT fn_logout('not-a-real-token') INTO v_result;
RAISE NOTICE 'Logout on fake token   (expect false): %', v_result;


-- ─────────────────────────────────────────────
-- DONE
-- ─────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════';
RAISE NOTICE 'All 7 tests completed.';
RAISE NOTICE '══════════════════════════════════════════════';

END;
$$;
