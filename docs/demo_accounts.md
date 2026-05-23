# Demo Staff Accounts

These accounts are local demo/test credentials. They are seeded by
[data/seed.sql](../data/seed.sql) on a fresh database and can be synced into an
existing database with [backend/manage_staff.py](../backend/manage_staff.py).

Passwords are intentionally simple and shared per role for classroom demos.
Do not reuse them outside this local project.

| Role | Username | Password |
| --- | --- | --- |
| Admin | `admin_user` | `Admin@1234` |
| Admin | `admin_02` | `Admin@1234` |
| Admin | `admin_03` | `Admin@1234` |
| Admin | `admin_04` | `Admin@1234` |
| Admin | `admin_05` | `Admin@1234` |
| Sales | `sales_mgr` | `Sales@1234` |
| Sales | `sales_02` | `Sales@1234` |
| Sales | `sales_03` | `Sales@1234` |
| Sales | `sales_04` | `Sales@1234` |
| Sales | `sales_05` | `Sales@1234` |
| Cashier | `cashier_01` | `Cash@1234` |
| Cashier | `cashier_02` | `Cash@1234` |
| Cashier | `cashier_03` | `Cash@1234` |
| Cashier | `cashier_04` | `Cash@1234` |
| Cashier | `cashier_05` | `Cash@1234` |
| User | `user_01` | `User@1234` |
| User | `user_02` | `User@1234` |
| User | `user_03` | `User@1234` |
| User | `user_04` | `User@1234` |
| User | `user_05` | `User@1234` |

Disabled negative-test account:

| Role | Username | Password | Status |
| --- | --- | --- | --- |
| User | `inactive_usr` | `Old@1234` | Disabled |

Role permissions:

| Role | Admin | Sales | Stock | View |
| --- | --- | --- | --- | --- |
| Admin | Yes | Yes | Yes | Yes |
| Sales | No | Yes | Yes | Yes |
| Cashier | No | Yes | No | Yes |
| User | No | No | No | Yes |
