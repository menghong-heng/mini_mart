-- =============================================================
-- SentinelDB - Oracle login smoke test
-- =============================================================

SET SERVEROUTPUT ON;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

DECLARE
    v_rc        SYS_REFCURSOR;
    v_token     VARCHAR2(64);
    v_expires   TIMESTAMP;
    v_username  VARCHAR2(100);
    v_role      VARCHAR2(50);
    v_admin     NUMBER;
    v_sales     NUMBER;
    v_stock     NUMBER;
    v_view      NUMBER;
    v_count     NUMBER;
    v_result    NUMBER;
    v_failed    NUMBER;

    PROCEDURE login_as(p_username VARCHAR2, p_password_md5 VARCHAR2, p_expected_role VARCHAR2) IS
    BEGIN
        v_rc := fn_login(
            p_username,
            p_password_md5,
            '127.0.0.1'
        );
        FETCH v_rc INTO v_token, v_expires, v_role, v_admin, v_sales, v_stock, v_view;
        CLOSE v_rc;

        DBMS_OUTPUT.PUT_LINE('LOGIN ' || p_username || ' => role=' || v_role || ', token=' || v_token);
        IF v_role <> p_expected_role THEN
            raise_application_error(-20901, 'Expected role ' || p_expected_role || ' but got ' || v_role);
        END IF;
    END;
BEGIN
    login_as('admin_user', '4de93544234adffbb681ed60ffcfb941', 'Admin');

    v_rc := fn_validate_session(v_token);
    FETCH v_rc INTO v_count, v_username, v_role, v_admin, v_sales, v_stock, v_view;
    IF v_rc%NOTFOUND THEN
        CLOSE v_rc;
        raise_application_error(-20902, 'Expected admin session to validate');
    END IF;
    CLOSE v_rc;

    v_result := fn_check_permission(v_token, 'admin');
    IF v_result <> 1 THEN
        raise_application_error(-20903, 'Expected admin permission to be allowed');
    END IF;

    v_result := fn_logout(v_token);
    IF v_result <> 1 THEN
        raise_application_error(-20904, 'Expected logout to return 1');
    END IF;

    v_rc := fn_validate_session(v_token);
    FETCH v_rc INTO v_count, v_username, v_role, v_admin, v_sales, v_stock, v_view;
    IF v_rc%FOUND THEN
        CLOSE v_rc;
        raise_application_error(-20905, 'Expected logged-out session to be invalid');
    END IF;
    CLOSE v_rc;

    login_as('sales_mgr', '9580312f024ea8140ad79dc2650396a9', 'Sales');
    v_result := fn_logout(v_token);

    login_as('cashier_01', 'f63da30b6ebd60c0f87061c737a6a52d', 'Cashier');
    v_result := fn_logout(v_token);

    login_as('user_01', '9eeaf04ead83d91063237f9e99d4caee', 'User');
    v_result := fn_logout(v_token);

    v_failed := 0;
    BEGIN
        v_rc := fn_login('admin_user', 'd7eea11dffaf0936611d58d3c5aff066', '127.0.0.1');
    EXCEPTION
        WHEN OTHERS THEN
            v_failed := 1;
            DBMS_OUTPUT.PUT_LINE('Expected failure: ' || SQLERRM);
    END;
    IF v_failed = 0 THEN
        CLOSE v_rc;
        raise_application_error(-20906, 'Wrong-password login should have failed');
    END IF;

    DBMS_OUTPUT.PUT_LINE('All Oracle login smoke checks passed.');
END;
/

COMMIT;
