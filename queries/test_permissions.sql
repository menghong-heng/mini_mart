-- =============================================================
-- SentinelDB — Role Access Permission Tests
-- Phase 4: Test each role's access permissions
-- =============================================================
-- Prerequisites (run in order on a fresh database):
--   \i schema/schema.sql
--   \i data/seed.sql
--   \i queries/auth.sql
--   \i queries/permissions.sql
--   \i queries/test_permissions.sql   ← this file
-- =============================================================
-- Expected permission matrix:
--
--   Role    | admin | sales | stock | view
--   --------|-------|-------|-------|------
--   Admin   | TRUE  | TRUE  | TRUE  | TRUE
--   Sales   | FALSE | TRUE  | TRUE  | TRUE
--   Cashier | FALSE | TRUE  | FALSE | TRUE
--   Viewer  | FALSE | FALSE | FALSE | TRUE
-- =============================================================

DO $$
DECLARE
    v_token     VARCHAR;
    v_actual    BOOLEAN;
    v_pass      INT := 0;
    v_fail      INT := 0;
    v_total     INT := 0;

    -- inline assert: compares actual vs expected, prints result, updates counters
    -- called as: PERFORM assert(label, actual, expected, v_pass, v_fail, v_total)
    -- (implemented inline below since PL/pgSQL nested functions aren't supported)
BEGIN

-- ══════════════════════════════════════════════════════════════
-- PART 1 — SYSTEMATIC MATRIX TEST  (16 assertions: 4 roles × 4 modules)
-- ══════════════════════════════════════════════════════════════

RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════════════';
RAISE NOTICE 'PART 1 — Systematic Permission Matrix (4 roles × 4 modules)';
RAISE NOTICE '══════════════════════════════════════════════════════════════';


-- ──────────────────────────────────────────────
-- ROLE: Admin  (expect all TRUE)
-- ──────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '[ ROLE: Admin ]';
SELECT out_token INTO v_token FROM fn_login('admin_user', md5('Admin@1234'), '10.0.0.1');

SELECT fn_check_permission(v_token, 'admin') INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  admin  module → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  admin  module → % (expected TRUE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'sales') INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  sales  module → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  sales  module → % (expected TRUE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'stock') INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  stock  module → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  stock  module → % (expected TRUE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'view')  INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  view   module → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  view   module → % (expected TRUE)', v_actual; END IF;

PERFORM fn_logout(v_token);


-- ──────────────────────────────────────────────
-- ROLE: Sales  (expect admin=FALSE, others TRUE)
-- ──────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '[ ROLE: Sales ]';
SELECT out_token INTO v_token FROM fn_login('sales_mgr', md5('Sales@1234'), '10.0.0.2');

SELECT fn_check_permission(v_token, 'admin') INTO v_actual;
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  admin  module → %  (correctly blocked)', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  admin  module → % (expected FALSE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'sales') INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  sales  module → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  sales  module → % (expected TRUE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'stock') INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  stock  module → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  stock  module → % (expected TRUE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'view')  INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  view   module → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  view   module → % (expected TRUE)', v_actual; END IF;

PERFORM fn_logout(v_token);


-- ──────────────────────────────────────────────
-- ROLE: Cashier  (expect sales=TRUE, view=TRUE, admin/stock=FALSE)
-- ──────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '[ ROLE: Cashier ]';
SELECT out_token INTO v_token FROM fn_login('cashier_01', md5('Cash@1234'), '10.0.0.3');

SELECT fn_check_permission(v_token, 'admin') INTO v_actual;
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  admin  module → %  (correctly blocked)', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  admin  module → % (expected FALSE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'sales') INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  sales  module → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  sales  module → % (expected TRUE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'stock') INTO v_actual;
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  stock  module → %  (correctly blocked)', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  stock  module → % (expected FALSE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'view')  INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  view   module → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  view   module → % (expected TRUE)', v_actual; END IF;

PERFORM fn_logout(v_token);


-- ──────────────────────────────────────────────
-- ROLE: Viewer  (expect only view=TRUE)
-- ──────────────────────────────────────────────
RAISE NOTICE '';
RAISE NOTICE '[ ROLE: Viewer ]';
SELECT out_token INTO v_token FROM fn_login('viewer_01', md5('View@1234'), '10.0.0.4');

SELECT fn_check_permission(v_token, 'admin') INTO v_actual;
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  admin  module → %  (correctly blocked)', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  admin  module → % (expected FALSE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'sales') INTO v_actual;
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  sales  module → %  (correctly blocked)', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  sales  module → % (expected FALSE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'stock') INTO v_actual;
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  stock  module → %  (correctly blocked)', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  stock  module → % (expected FALSE)', v_actual; END IF;

SELECT fn_check_permission(v_token, 'view')  INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  view   module → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  view   module → % (expected TRUE)', v_actual; END IF;

PERFORM fn_logout(v_token);


-- ══════════════════════════════════════════════════════════════
-- PART 2 — SCENARIO-BASED TESTS  (real-world access situations)
-- ══════════════════════════════════════════════════════════════

RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════════════';
RAISE NOTICE 'PART 2 — Scenario-Based Access Tests';
RAISE NOTICE '══════════════════════════════════════════════════════════════';


-- Scenario 1: Admin reads audit logs → ALLOWED
RAISE NOTICE '';
RAISE NOTICE '[ Scenario 1 ]  Admin reads audit logs  →  expect ALLOWED';
SELECT out_token INTO v_token FROM fn_login('admin_user', md5('Admin@1234'), '10.0.0.1');
SELECT fn_check_permission(v_token, 'admin') INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  ALLOWED — admin can access Admin module';
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  admin should be allowed into Admin module'; END IF;
PERFORM fn_logout(v_token);


-- Scenario 2: Cashier reads audit logs → BLOCKED
RAISE NOTICE '';
RAISE NOTICE '[ Scenario 2 ]  Cashier reads audit logs  →  expect BLOCKED';
SELECT out_token INTO v_token FROM fn_login('cashier_01', md5('Cash@1234'), '10.0.0.3');
SELECT fn_check_permission(v_token, 'admin') INTO v_actual;
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  BLOCKED — cashier cannot access Admin module';
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  cashier must be blocked from Admin module'; END IF;
PERFORM fn_logout(v_token);


-- Scenario 3: Sales views stock inventory → ALLOWED
RAISE NOTICE '';
RAISE NOTICE '[ Scenario 3 ]  Sales views stock inventory  →  expect ALLOWED';
SELECT out_token INTO v_token FROM fn_login('sales_mgr', md5('Sales@1234'), '10.0.0.2');
SELECT fn_check_permission(v_token, 'stock') INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  ALLOWED — sales can access Stock module';
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  sales should be allowed into Stock module'; END IF;
PERFORM fn_logout(v_token);


-- Scenario 4: Cashier views stock inventory → BLOCKED
RAISE NOTICE '';
RAISE NOTICE '[ Scenario 4 ]  Cashier views stock inventory  →  expect BLOCKED';
SELECT out_token INTO v_token FROM fn_login('cashier_01', md5('Cash@1234'), '10.0.0.3');
SELECT fn_check_permission(v_token, 'stock') INTO v_actual;
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  BLOCKED — cashier cannot access Stock module';
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  cashier must be blocked from Stock module'; END IF;
PERFORM fn_logout(v_token);


-- Scenario 5: Viewer tries to create an order → BLOCKED
RAISE NOTICE '';
RAISE NOTICE '[ Scenario 5 ]  Viewer creates an order  →  expect BLOCKED';
SELECT out_token INTO v_token FROM fn_login('viewer_01', md5('View@1234'), '10.0.0.4');
SELECT fn_check_permission(v_token, 'sales') INTO v_actual;
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  BLOCKED — viewer cannot access Sales module';
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  viewer must be blocked from Sales module'; END IF;
PERFORM fn_logout(v_token);


-- Scenario 6: Viewer reads product list → ALLOWED
RAISE NOTICE '';
RAISE NOTICE '[ Scenario 6 ]  Viewer reads product list  →  expect ALLOWED';
SELECT out_token INTO v_token FROM fn_login('viewer_01', md5('View@1234'), '10.0.0.4');
SELECT fn_check_permission(v_token, 'view') INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  ALLOWED — viewer can access View module';
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  viewer should be allowed into View module'; END IF;
PERFORM fn_logout(v_token);


-- Scenario 7: Sales tries to modify system config → BLOCKED
RAISE NOTICE '';
RAISE NOTICE '[ Scenario 7 ]  Sales modifies system config  →  expect BLOCKED';
SELECT out_token INTO v_token FROM fn_login('sales_mgr', md5('Sales@1234'), '10.0.0.2');
SELECT fn_check_permission(v_token, 'admin') INTO v_actual;
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  BLOCKED — sales cannot access Admin module';
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  sales must be blocked from Admin module'; END IF;
PERFORM fn_logout(v_token);


-- Scenario 8: Cashier processes a sale → ALLOWED
RAISE NOTICE '';
RAISE NOTICE '[ Scenario 8 ]  Cashier processes a sale  →  expect ALLOWED';
SELECT out_token INTO v_token FROM fn_login('cashier_01', md5('Cash@1234'), '10.0.0.3');
SELECT fn_check_permission(v_token, 'sales') INTO v_actual;
v_total := v_total + 1;
IF v_actual = TRUE  THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  ALLOWED — cashier can access Sales module';
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  cashier should be allowed into Sales module'; END IF;
PERFORM fn_logout(v_token);


-- ══════════════════════════════════════════════════════════════
-- PART 3 — EDGE CASE TESTS  (invalid / logged-out tokens)
-- ══════════════════════════════════════════════════════════════

RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════════════';
RAISE NOTICE 'PART 3 — Edge Case Tests';
RAISE NOTICE '══════════════════════════════════════════════════════════════';


-- Edge 1: Completely invalid token → all modules FALSE
RAISE NOTICE '';
RAISE NOTICE '[ Edge 1 ]  Invalid token — all modules must return FALSE';
v_actual := fn_check_permission('not-a-valid-token-xyz', 'admin');
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  admin  → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  admin  → % (expected FALSE)', v_actual; END IF;

v_actual := fn_check_permission('not-a-valid-token-xyz', 'sales');
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  sales  → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  sales  → % (expected FALSE)', v_actual; END IF;

v_actual := fn_check_permission('not-a-valid-token-xyz', 'stock');
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  stock  → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  stock  → % (expected FALSE)', v_actual; END IF;

v_actual := fn_check_permission('not-a-valid-token-xyz', 'view');
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  view   → %', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  view   → % (expected FALSE)', v_actual; END IF;


-- Edge 2: Valid token, then logged out → all modules FALSE
RAISE NOTICE '';
RAISE NOTICE '[ Edge 2 ]  Logged-out token — all modules must return FALSE';
SELECT out_token INTO v_token FROM fn_login('cashier_02', md5('Cash@1234'), '10.0.0.5');
PERFORM fn_logout(v_token);   -- logout immediately

v_actual := fn_check_permission(v_token, 'sales');
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  sales after logout → %  (session correctly dead)', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  sales after logout → % (expected FALSE)', v_actual; END IF;

v_actual := fn_check_permission(v_token, 'view');
v_total := v_total + 1;
IF v_actual = FALSE THEN v_pass := v_pass + 1; RAISE NOTICE '  PASS  view  after logout → %  (session correctly dead)', v_actual;
ELSE                      v_fail := v_fail + 1; RAISE NOTICE '  FAIL  view  after logout → % (expected FALSE)', v_actual; END IF;


-- Edge 3: Disabled user account → login must be rejected
RAISE NOTICE '';
RAISE NOTICE '[ Edge 3 ]  Disabled account — login must be rejected';
v_total := v_total + 1;
BEGIN
    SELECT out_token INTO v_token FROM fn_login('inactive_usr', md5('Old@1234'), '10.0.0.9');
    -- should never reach here
    v_fail := v_fail + 1;
    RAISE NOTICE '  FAIL  inactive_usr was allowed to log in (must be blocked)';
EXCEPTION
    WHEN OTHERS THEN
        v_pass := v_pass + 1;
        RAISE NOTICE '  PASS  Login rejected — %', SQLERRM;
END;


-- ══════════════════════════════════════════════════════════════
-- FINAL SUMMARY
-- ══════════════════════════════════════════════════════════════

RAISE NOTICE '';
RAISE NOTICE '══════════════════════════════════════════════════════════════';
RAISE NOTICE 'RESULTS:  % / % passed   (%  failed)', v_pass, v_total, v_fail;
RAISE NOTICE '══════════════════════════════════════════════════════════════';

IF v_fail = 0 THEN
    RAISE NOTICE 'STATUS:  ALL TESTS PASSED — permission matrix is correct.';
ELSE
    RAISE NOTICE 'STATUS:  % TEST(S) FAILED — review FAIL lines above.', v_fail;
END IF;

RAISE NOTICE '';

END;
$$;


-- ══════════════════════════════════════════════════════════════
-- STATIC REFERENCE — full permission matrix from the database
-- ══════════════════════════════════════════════════════════════
SELECT * FROM v_role_permissions;
