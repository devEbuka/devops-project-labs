# Inventory Management API — AWS lab workload

A deliberately small **stateless FastAPI REST service** backed by PostgreSQL, designed for an AWS ALB + EC2 Auto Scaling Group + RDS deployment. **Infrastructure/Terraform is not included.**

## Features

- JWT authentication: user registration, login, Argon2id password hashes, short-lived tokens
- PostgreSQL-backed roles: viewer (read-only) and admin (inventory writes)
- Per-account failed-login lockout (5 attempts / 15 minutes); no centralized IP rate limiting
- Product CRUD, stock adjustment history, inventory summary
- PostgreSQL row locking on stock changes to avoid lost updates
- `/health` liveness (no DB dependency), `/ready` PostgreSQL readiness
- `/instance` identifies the serving container/instance for ALB testing
- OpenAPI docs at `/docs`
- Docker container runs as a non-root user; no persistent local data
- Database schema initialized separately, not on every container start

## Local run (Docker Compose)

Requires Docker Engine with Compose plugin.

```bash
cp .env.example .env
# Edit .env and replace JWT_SECRET with a random value (32+ characters).
docker compose up -d --build db
docker compose --profile setup run --rm init
docker compose up -d --build api
curl http://localhost:8055/health
curl http://localhost:8055/ready
```

Open http://localhost:8055/docs for the interactive API. To remove local data: `docker compose down -v` (deletes the PostgreSQL volume).

## Authentication and inventory walkthrough

Registering a user creates a **viewer**, not an administrator:

```bash
curl -X POST http://localhost:8055/auth/register -H 'Content-Type: application/json' \
  -d '{"email":"viewer@example.com","password":"replace-with-a-unique-12plus-password"}'
```

Create the initial administrator **once**, after schema initialization. In local Docker Compose, pass secrets through your terminal or a secure local environment, not Git. For example:

```bash
# Set ADMIN_EMAIL and ADMIN_PASSWORD in your shell first.
docker compose --profile setup run --rm -e ADMIN_EMAIL -e ADMIN_PASSWORD init \
  python -m scripts.create_admin
```

Login with JSON credentials:

```bash
curl -X POST http://localhost:8055/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"viewer@example.com","password":"replace-with-a-unique-12plus-password"}'
```

Copy the returned `access_token` and use `Authorization: Bearer <token>` for protected requests. In Swagger at `/docs`, click **Authorize** and paste the token. Admin accounts may write products and adjust stock; viewer accounts may read products, movements, and summaries. `/health` and `/ready` remain public for infrastructure health checks. `/instance` requires a token.

**Security caveat:** The agreed HTTP-only ALB means passwords and tokens are **not encrypted between clients and the ALB**. Use disposable credentials and synthetic data only; restrict ALB ingress to your own IP, and never reuse real passwords. For actual production use, enable HTTPS, add distributed IP-based login/registration rate limiting, and evaluate stronger account management, audit logs, and token revocation.

## Example admin inventory requests

```bash
TOKEN='paste-admin-access-token-here'
curl -X POST http://localhost:8055/products -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"sku":"SKU-001","name":"Laptop","price":"750.00","quantity":10}'
curl http://localhost:8055/products -H "Authorization: Bearer $TOKEN"
curl -X POST http://localhost:8055/products/1/stock -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"delta":-2,"reason":"Sold two units"}'
curl http://localhost:8055/inventory/summary -H "Authorization: Bearer $TOKEN"
```

## AWS integration contract

| Item | Value |
| --- | --- |
| Container listening port | `8055` |
| ALB health check | `GET /health` returns 200 |
| DB readiness | `GET /ready` returns 200 or 503 |
| Database | PostgreSQL (RDS) |
| Required env vars | `DATABASE_URL`, `JWT_SECRET` (random 32+ character value; identical on all instances) |
| Optional env vars | `INSTANCE_ID`, `DB_POOL_SIZE`, `DB_MAX_OVERFLOW`, `JWT_EXPIRE_MINUTES` (default 30) |
| Image | Build and push to ECR with immutable tag/digest |
| Migrations | `python -m scripts.init_db` run **once** via SSM or dedicated initializer |
| Runtime | `uvicorn app.main:app --host 0.0.0.0 --port 8055` |

### PostgreSQL TLS

For RDS, use a verified TLS connection. With psycopg, the connection string can include `sslmode=verify-full&sslrootcert=/path/to/rds-ca-bundle.pem` (URL-encode special characters). Mount the official AWS RDS CA bundle inside the container at that path and use the **RDS endpoint hostname** (not an IP) so hostname verification succeeds. A TLS bundle is not included in this repo. Validate this before AWS deployment.

### Secrets and IAM

The application expects `DATABASE_URL` as an environment variable. **Do not put its password in Terraform state, user data, Git, or container images.** A secure bootstrap process should retrieve the app user's credential from Secrets Manager using the instance profile, assemble the URL safely, and start the container without printing credentials. The RDS-managed master secret is **not** the application credential. Create a dedicated least-privilege DB user during initialization and store its credential separately; choose a secure process that does not introduce it into Terraform state. Store `JWT_SECRET` in Secrets Manager too, and supply the **same value to every EC2 instance**. Never log secrets or the connection string.

### Database initialization

`python -m scripts.init_db` creates missing tables, including the users table; it is **not** a versioned migration framework. For this fixed lab schema it is sufficient, but future schema changes require proper Alembic migrations. Run initialization once, after creating the app user and granting privileges, before starting ASG instances. Never run schema setup on every instance launch.

### Production-style cautions

- **Authentication is implemented, but HTTP is unencrypted.** Use synthetic lab data and disposable credentials only. Restrict ALB access to your IP and tear down promptly. Login throttling is per account in PostgreSQL, not a substitute for IP-based rate limiting.
- SQLAlchemy's connection pool defaults to 5 + 5 overflow per process; size RDS `max_connections` for up to 4 EC2 instances, or reduce the pool settings.
- `/health` reports process liveness only; `/ready` checks PostgreSQL. CloudWatch should alert on readiness failures separately.
- Use a single application process per container initially. No Redis, file storage, or S3 integration is needed for this API.
- App-specific RDS database initialization and credential creation should be handled by your SSM orchestration, not Terraform provisioning secrets in state.
- Before any real production use, add HTTPS, distributed IP rate limiting, password reset/verification, security event auditing, token revocation strategy, and versioned migrations.

## Suggested AWS validation

1. Initialize the schema and launch one EC2 app instance.
2. Verify ALB `/health` and direct application `/ready` using SSM.
3. Bootstrap an admin, register a viewer, log in, and confirm admin/viewer permissions. Then create products and adjust stock through the ALB.
4. Call `/instance` repeatedly while ASG has two healthy instances; confirm requests are served by different instances.
5. Replace an instance; verify existing products remain because state lives in RDS.
6. Load-test CPU and ALB requests-per-target scaling; inspect CloudWatch and SNS alarms.
7. Update immutable ECR image and run ASG Instance Refresh.
8. Destroy lab infrastructure; review retained snapshots and S3 backend separately.

## Automated authentication tests

```bash
python -m pip install -r requirements.txt pytest httpx
python -m pytest -q
```

Tests use SQLite as a lightweight substitute for PostgreSQL; they do not replace Docker/PostgreSQL integration testing.
