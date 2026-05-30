-- =============================================================
-- SentinelDB - Oracle RBAC permission smoke test
-- =============================================================

SET SERVEROUTPUT ON;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

DECLARE
    v_rc      SYS_REFCURSOR;
    v_token   VARCHAR2(64);
    v_expires TIMESTAMP;
    v_role    VARCHAR2(50);
    v_admin   NUMBER;
    v_sales   NUMBER;
    v_stock   NUMBER;
    v_view    NUMBER;
    v_actual  NUMBER;

    PROCEDURE assert_permission(
        p_username VARCHAR2,
        p_password_md5 VARCHAR2,
        p_role     VARCHAR2,
        p_module   VARCHAR2,
        p_expected NUMBER
    ) IS
    BEGIN
        v_rc := fn_login(
            p_username,
            p_password_md5,
            '127.0.0.1'
        );
        FETCH v_rc INTO v_token, v_expires, v_role, v_admin, v_sales, v_stock, v_view;
        CLOSE v_rc;

        IF v_role <> p_role THEN
            raise_application_error(-20910, p_username || ' expected role ' || p_role || ' but got ' || v_role);
        END IF;

        v_actual := fn_check_permission(v_token, p_module);
        IF v_actual <> p_expected THEN
            raise_application_error(
                -20911,
                p_username || ' module ' || p_module || ' expected ' || p_expected || ' but got ' || v_actual
            );
        END IF;

        v_actual := fn_logout(v_token);
        DBMS_OUTPUT.PUT_LINE('PASS ' || p_username || ' ' || p_module || ' => ' || p_expected);
    END;
BEGIN
    assert_permission('admin_user', '4de93544234adffbb681ed60ffcfb941', 'Admin', 'admin', 1);
    assert_permission('admin_user', '4de93544234adffbb681ed60ffcfb941', 'Admin', 'sales', 1);
    assert_permission('admin_user', '4de93544234adffbb681ed60ffcfb941', 'Admin', 'stock', 1);
    assert_permission('admin_user', '4de93544234adffbb681ed60ffcfb941', 'Admin', 'view', 1);

    assert_permission('sales_mgr', '9580312f024ea8140ad79dc2650396a9', 'Sales', 'admin', 0);
    assert_permission('sales_mgr', '9580312f024ea8140ad79dc2650396a9', 'Sales', 'sales', 1);
    assert_permission('sales_mgr', '9580312f024ea8140ad79dc2650396a9', 'Sales', 'stock', 1);
    assert_permission('sales_mgr', '9580312f024ea8140ad79dc2650396a9', 'Sales', 'view', 1);

    assert_permission('cashier_01', 'f63da30b6ebd60c0f87061c737a6a52d', 'Cashier', 'admin', 0);
    assert_permission('cashier_01', 'f63da30b6ebd60c0f87061c737a6a52d', 'Cashier', 'sales', 1);
    assert_permission('cashier_01', 'f63da30b6ebd60c0f87061c737a6a52d', 'Cashier', 'stock', 0);
    assert_permission('cashier_01', 'f63da30b6ebd60c0f87061c737a6a52d', 'Cashier', 'view', 1);

    assert_permission('user_01', '9eeaf04ead83d91063237f9e99d4caee', 'User', 'admin', 0);
    assert_permission('user_01', '9eeaf04ead83d91063237f9e99d4caee', 'User', 'sales', 0);
    assert_permission('user_01', '9eeaf04ead83d91063237f9e99d4caee', 'User', 'stock', 0);
    assert_permission('user_01', '9eeaf04ead83d91063237f9e99d4caee', 'User', 'view', 1);

    v_actual := fn_check_permission('not-a-real-token', 'view');
    IF v_actual <> 0 THEN
        raise_application_error(-20912, 'Invalid token should not have view permission');
    END IF;

    DBMS_OUTPUT.PUT_LINE('All Oracle RBAC permission checks passed.');
END;
/

COMMIT;
