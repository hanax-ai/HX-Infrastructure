# HX Infrastructure: Service Connection Contracts

This document is the single source of truth for connecting to core database and cache services. All applications, services, and scripts **must** adhere to these standards.

---

### PostgreSQL

* [cite_start]**Canonical Endpoint**: `hx-postgres-server.dev-test.hana-x.ai:5432` [cite: 1293]
* [cite_start]**Target Database**: `hx_app_db` [cite: 1289]
* **Authentication Policy**:
    * **Primary (Passwordless)**: Kerberos/GSSAPI for all domain-joined services on the `192.168.10.0/24` subnet.
    * [cite_start]**Fallback (Password)**: For services that cannot use Kerberos, the standard credential is user `hx_app` with the password `Major8859!`. [cite: 1286, 1288]
* **Connection Strings**:
    * **SSO Path**: `postgresql://hx_app@hx-postgres-server.dev-test.hana-x.ai:5432/hx_app_db`
    * [cite_start]**Fallback Path**: `postgresql://hx_app:Major8859!@hx-postgres-server.dev-test.hana-x.ai:5432/hx_app_db` [cite: 1293]
* **TLS/SSL Policy**: Server-side TLS is the standard. Clients **must** be configured to trust the HX Root CA, with `sslmode=verify-full` as the target state.

---

### Redis

* [cite_start]**Canonical Endpoint**: `hx-postgres-server.dev-test.hana-x.ai:6379` [cite: 1331]
* **Authentication Policy**:
    * [cite_start]**Primary**: Password-based authentication using `requirepass`. [cite: 1311]
    * [cite_start]**Password**: The standard password is `Major8859!`. [cite: 1311]
* [cite_start]**Connection String**: `redis://default:Major8859!@hx-postgres-server.dev-test.hana-x.ai:6379` [cite: 1331]
* [cite_start]**TLS/SSL Policy**: TLS is **disabled** for Redis, as access is restricted to the trusted internal LAN. [cite: 1332]
