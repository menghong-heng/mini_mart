#!/usr/bin/env python3
"""
SentinelDB — Staff credential management.

Edit the STAFF list below, then run:

    python manage_staff.py              # sync all staff to the database
    python manage_staff.py --list       # print current staff + roles
    python manage_staff.py --reset-password <username>   # interactive pw change
    python manage_staff.py --deactivate <username>       # disable account
    python manage_staff.py --activate   <username>       # re-enable account

Reads DATABASE_URL from .env (same file used by the FastAPI app).
Passwords are stored as md5(plaintext) to match fn_login expectations.
"""

import argparse
import getpass
import hashlib
import os
import sys
import psycopg
from psycopg.rows import dict_row   
from dotenv import load_dotenv

load_dotenv()

# ──────────────────────────────────────────────────────────────────
#  Edit this list, then run:  python manage_staff.py
#
#  Valid roles: Admin, Sales, Cashier, Viewer
#  "email"  — Gmail or any address; staff can sign in with email OR username
#  "active" — set False to disable an account without deleting it
# ──────────────────────────────────────────────────────────────────
STAFF = [
    {"username": "Sattha",      "email": "adminSattha@gmail.com",    "password": "12345",       "role": "Admin",   "active": True},
    {"username": "MengHong",   "email": "sales@gmail.com",    "password": "Sales@1234",  "role": "Sales",   "active": True},
    {"username": "cashier_01",  "email": "cashier@gmail.com",  "password": "Cash@1234",   "role": "Cashier", "active": True},
    {"username": "viewer_01",   "email": "viewer@gmail.com",   "password": "View@1234",   "role": "Viewer",  "active": True},
]
# ──────────────────────────────────────────────────────────────────


def _md5(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


def _get_conn():
    db_url = os.getenv(
        "DATABASE_URL",
        "postgresql://postgres:postgres@localhost:5432/sentineldb",
    )
    return psycopg.connect(db_url, row_factory=dict_row)


def sync_staff(conn) -> None:
    added = updated = skipped = 0

    with conn.cursor() as cur:
        for s in STAFF:
            cur.execute("SELECT role_id FROM roles WHERE role_name = %s", (s["role"],))
            role_row = cur.fetchone()
            if not role_row:
                print(f"  SKIP  {s['username']!r}: role {s['role']!r} not found in DB")
                skipped += 1
                continue

            pw_hash = _md5(s["password"])
            role_id = role_row["role_id"]
            email   = s.get("email") or None

            # If another user already owns this email, clear it first to avoid
            # a unique-constraint violation on the upsert below.
            if email:
                cur.execute(
                    "UPDATE users SET email = NULL WHERE email = %s AND username != %s",
                    (email, s["username"]),
                )

            cur.execute(
                """INSERT INTO users (username, password_hash, role_id, is_active, email)
                   VALUES (%s, %s, %s, %s, %s)
                   ON CONFLICT (username) DO UPDATE
                       SET password_hash = EXCLUDED.password_hash,
                           role_id       = EXCLUDED.role_id,
                           is_active     = EXCLUDED.is_active,
                           email         = EXCLUDED.email
                   RETURNING (xmax = 0) AS inserted""",
                (s["username"], pw_hash, role_id, s["active"], email),
            )
            row = cur.fetchone()
            if row["inserted"]:
                added += 1
                print(f"  ADD    {s['username']!r}  →  role={s['role']}, email={email or '—'}")
            else:
                updated += 1
                print(f"  UPDATE {s['username']!r}  →  role={s['role']}, email={email or '—'}, active={s['active']}")

    conn.commit()
    print(f"\nDone — Added: {added}, Updated: {updated}, Skipped: {skipped}")


def list_staff(conn) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """SELECT u.username, u.email, r.role_name, u.is_active, u.last_login
               FROM   users u
               JOIN   roles r ON r.role_id = u.role_id
               ORDER  BY r.role_name, u.username"""
        )
        rows = cur.fetchall()

    if not rows:
        print("No staff users found.")
        return

    print(f"\n{'USERNAME':<20} {'EMAIL':<30} {'ROLE':<12} {'ACTIVE':<8} LAST LOGIN")
    print("─" * 82)
    for r in rows:
        last   = r["last_login"].strftime("%Y-%m-%d %H:%M") if r["last_login"] else "never"
        status = "yes" if r["is_active"] else "no"
        email  = r["email"] or "—"
        print(f"{r['username']:<20} {email:<30} {r['role_name']:<12} {status:<8} {last}")
    print()


def reset_password(conn, username: str) -> None:
    with conn.cursor() as cur:
        cur.execute("SELECT user_id FROM users WHERE username = %s", (username,))
        if not cur.fetchone():
            sys.exit(f"Error: user {username!r} not found.")

    new_pw  = getpass.getpass(f"New password for {username!r}: ")
    confirm = getpass.getpass("Confirm password: ")
    if new_pw != confirm:
        sys.exit("Error: passwords do not match.")
    if len(new_pw) < 6:
        sys.exit("Error: password must be at least 6 characters.")

    with conn.cursor() as cur:
        cur.execute(
            "UPDATE users SET password_hash = %s WHERE username = %s",
            (_md5(new_pw), username),
        )
    conn.commit()
    print(f"Password updated for {username!r}.")


def set_active(conn, username: str, active: bool) -> None:
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE users SET is_active = %s WHERE username = %s RETURNING user_id",
            (active, username),
        )
        if not cur.fetchone():
            conn.rollback()
            sys.exit(f"Error: user {username!r} not found.")

    conn.commit()
    state = "activated" if active else "deactivated"
    print(f"User {username!r} {state}.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SentinelDB staff management",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""examples:
  python manage_staff.py                          sync STAFF list to DB
  python manage_staff.py --list                   show all staff
  python manage_staff.py --reset-password alice   change alice's password
  python manage_staff.py --deactivate alice       disable alice's account
  python manage_staff.py --activate   alice       re-enable alice's account""",
    )
    parser.add_argument("--list",           action="store_true",  help="List all staff users")
    parser.add_argument("--reset-password", metavar="USERNAME",   help="Reset a user's password")
    parser.add_argument("--deactivate",     metavar="USERNAME",   help="Disable a user account")
    parser.add_argument("--activate",       metavar="USERNAME",   help="Re-enable a user account")
    args = parser.parse_args()

    conn = _get_conn()
    try:
        if args.list:
            list_staff(conn)
        elif args.reset_password:
            reset_password(conn, args.reset_password)
        elif args.deactivate:
            set_active(conn, args.deactivate, False)
        elif args.activate:
            set_active(conn, args.activate, True)
        else:
            print("Syncing STAFF list to database…")
            sync_staff(conn)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
