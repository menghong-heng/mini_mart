-- =============================================================
-- SentinelDB — Customer Authentication Extension
-- Two new tables + four PL/pgSQL functions for customer self-service
-- auth that runs parallel to (and never overlaps with) staff RBAC.
-- =============================================================
-- Run this file AFTER schema.sql and seed.sql.
-- Tables:
--   customer_accounts  — stores customer credentials (linked to customers table)
--   customer_sessions  — one active token per customer account
-- Functions:
--   fn_customer_signup(email, pw_md5, full_name, phone, ip) → (token, expires, customer_id, name)
--   fn_customer_login(email, pw_md5, ip)                   → (token, expires, customer_id, name)
--   fn_customer_validate_session(token)                    → (account_id, customer_id, email, name)
--   fn_customer_logout(token)                              → BOOLEAN
-- =============================================================

-- ─────────────────────────────────────────────
-- Tables
-- ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS customer_accounts (
    customer_account_id SERIAL          PRIMARY KEY,
    email               VARCHAR(255)    NOT NULL UNIQUE,
    password_hash       VARCHAR(64)     NOT NULL,
    customer_id         INT             NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at       TIMESTAMP
);

CREATE TABLE IF NOT EXISTS customer_sessions (
    session_id          SERIAL          PRIMARY KEY,
    customer_account_id INT             NOT NULL
                            REFERENCES customer_accounts(customer_account_id) ON DELETE CASCADE,
    token_hash          VARCHAR(64)     NOT NULL UNIQUE,
    expires_at          TIMESTAMP       NOT NULL,
    ip_address          VARCHAR(45),
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_customer_session_expiry CHECK (expires_at > created_at)
);


-- ─────────────────────────────────────────────
-- fn_customer_signup
-- ─────────────────────────────────────────────
-- Creates a new customer record (or links to an existing one by email),
-- creates a customer_accounts credential row, auto-logs in by opening a
-- session, and returns the session token.
--
-- The application must send md5(plaintext_password) as p_password_md5
-- to match the convention used by fn_login for staff.

CREATE OR REPLACE FUNCTION fn_customer_signup(
    p_email        VARCHAR,
    p_password_md5 VARCHAR,
    p_full_name    VARCHAR,
    p_phone        VARCHAR    DEFAULT NULL,
    p_ip_address   VARCHAR    DEFAULT NULL
)
RETURNS TABLE (
    out_token       VARCHAR,
    out_expires     TIMESTAMP,
    out_customer_id INT,
    out_full_name   VARCHAR,
    out_phone       VARCHAR
) AS $$
DECLARE
    v_customer_id INT;
    v_account_id  INT;
    v_token       VARCHAR;
    v_expires     TIMESTAMP;
BEGIN
    -- Reject if an account with this email already exists
    IF EXISTS (SELECT 1 FROM customer_accounts WHERE email = p_email) THEN
        RAISE EXCEPTION 'SIGNUP_FAIL: an account with this email already exists';
    END IF;

    -- Re-use existing customers row if email matches; otherwise create one
    SELECT customer_id INTO v_customer_id
    FROM   customers
    WHERE  email = p_email;

    IF NOT FOUND THEN
        INSERT INTO customers (name, email, phone)
        VALUES (p_full_name, p_email, p_phone)
        RETURNING customer_id INTO v_customer_id;
    END IF;

    -- Create the credential record
    INSERT INTO customer_accounts (email, password_hash, customer_id)
    VALUES (p_email, p_password_md5, v_customer_id)
    RETURNING customer_account_id INTO v_account_id;

    -- Auto-login: generate a 24-hour session token
    v_token   := md5(random()::text || clock_timestamp()::text || p_email);
    v_expires := clock_timestamp() + INTERVAL '24 hours';

    INSERT INTO customer_sessions (customer_account_id, token_hash, expires_at, ip_address)
    VALUES (v_account_id, v_token, v_expires, p_ip_address);

    RETURN QUERY
    SELECT v_token, v_expires, v_customer_id, c.name, c.phone
    FROM   customers c
    WHERE  c.customer_id = v_customer_id;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────
-- fn_customer_login
-- ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_customer_login(
    p_email        VARCHAR,
    p_password_md5 VARCHAR,
    p_ip_address   VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    out_token       VARCHAR,
    out_expires     TIMESTAMP,
    out_customer_id INT,
    out_full_name   VARCHAR,
    out_phone       VARCHAR
) AS $$
DECLARE
    v_account_id  INT;
    v_customer_id INT;
    v_is_active   BOOLEAN;
    v_token       VARCHAR;
    v_expires     TIMESTAMP;
BEGIN
    SELECT ca.customer_account_id, ca.customer_id, ca.is_active
    INTO   v_account_id, v_customer_id, v_is_active
    FROM   customer_accounts ca
    WHERE  ca.email = p_email AND ca.password_hash = p_password_md5;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'AUTH_FAIL: invalid email or password';
    END IF;

    IF NOT v_is_active THEN
        RAISE EXCEPTION 'AUTH_FAIL: account is disabled';
    END IF;

    v_token   := md5(random()::text || clock_timestamp()::text || p_email);
    v_expires := clock_timestamp() + INTERVAL '24 hours';

    -- Single-session policy: invalidate existing active sessions
    UPDATE customer_sessions
    SET    is_active = FALSE
    WHERE  customer_account_id = v_account_id AND is_active = TRUE;

    INSERT INTO customer_sessions (customer_account_id, token_hash, expires_at, ip_address)
    VALUES (v_account_id, v_token, v_expires, p_ip_address);

    UPDATE customer_accounts
    SET    last_login_at = clock_timestamp()
    WHERE  customer_account_id = v_account_id;

    RETURN QUERY
    SELECT v_token, v_expires, v_customer_id, c.name, c.phone
    FROM   customers c
    WHERE  c.customer_id = v_customer_id;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────
-- fn_customer_validate_session
-- ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_customer_validate_session(
    p_token_hash VARCHAR
)
RETURNS TABLE (
    out_customer_account_id INT,
    out_customer_id         INT,
    out_email               VARCHAR,
    out_full_name           VARCHAR,
    out_phone               VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT ca.customer_account_id, ca.customer_id, ca.email, c.name, c.phone
    FROM   customer_sessions cs
    JOIN   customer_accounts ca ON ca.customer_account_id = cs.customer_account_id
    JOIN   customers         c  ON c.customer_id          = ca.customer_id
    WHERE  cs.token_hash = p_token_hash
      AND  cs.is_active  = TRUE
      AND  cs.expires_at > clock_timestamp()
      AND  ca.is_active  = TRUE;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────
-- fn_customer_logout
-- ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_customer_logout(
    p_token_hash VARCHAR
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE customer_sessions
    SET    is_active = FALSE
    WHERE  token_hash = p_token_hash AND is_active = TRUE;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;


-- =============================================================
-- DEMO / TEST USAGE
-- =============================================================
-- Step 1 — Sign up a new customer
-- SELECT * FROM fn_customer_signup(
--     'alice@example.com', md5('mypassword'), 'Alice Smith', '012-345-6789', '127.0.0.1'
-- );
--
-- Step 2 — Log in with that account (copy the returned token)
-- SELECT * FROM fn_customer_login('alice@example.com', md5('mypassword'), '127.0.0.1');
--
-- Step 3 — Validate the session token
-- SELECT * FROM fn_customer_validate_session('<paste token here>');
--
-- Step 4 — Logout
-- SELECT fn_customer_logout('<paste token here>');
