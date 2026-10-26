# Implementation Notes — Inventory Management API

> **Status:** Completed — October 26, 2026
> **Environment:** AWS `us-west-1`; local terminal: Git Bash on Windows

## 1. Goal and Scope

Build AWS infrastructure with Terraform, deploy a containerized FastAPI inventory service to private EC2, use PostgreSQL on RDS, and expose the application through an ALB. Automate **remote execution** with SSM and Bash scripts; reserve a fully automated CI/CD pipeline for a later project.

## 2. Project Structure and Terraform

Terraform environment: `terraform/environments/dev`.

Modules implemented: `networking`, `security-groups`, `compute`, `database`, `iam`, `secrets-manager`, `ecr`, `deployment_storage`, and `alb`.

Key configuration decisions:

- VPC CIDR `10.0.0.0/16`, with public, private application, and private database subnet tiers.
- Private Ubuntu EC2 instance (`t3.micro`) running Docker and the AWS CLI.
- PostgreSQL RDS (`db.t3.micro`) with RDS-managed master credentials in Secrets Manager.
- Application host port `8000` mapped to container port `8055`.
- ALB in public subnets, forwarding HTTP port `80` to the EC2 target on port `8000`.
- SSM Run Command instead of inbound SSH for deployment and diagnostics.

Useful Terraform commands:

```bash
terraform -chdir=terraform/environments/dev init
terraform -chdir=terraform/environments/dev fmt -recursive
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/environments/dev plan
terraform -chdir=terraform/environments/dev apply
terraform -chdir=terraform/environments/dev output
```

**Key rule:** A successful Terraform apply proves the declared resources were reconciled; it does not prove the application responds correctly or that the original architecture is complete.

## 3. Build and Publish the Container

The Dockerfile uses `python:3.12-slim`, installs dependencies, copies the application and initialization scripts, and runs Uvicorn as a non-root user on port `8055`.

```bash
docker build -t inventory-api:v1 .
```

A local container startup test confirmed Uvicorn launched. The image was tagged and pushed to the ECR repository **`dev-inventory_api`**, tag **`v1`**, in `us-west-1`.

The deployed image was verified through `aws ecr describe-images` and later pulled successfully on EC2.

## 4. Versioned Deployment Artifacts

Deployment files:

```text
deploy/
├── compose.yaml
├── deploy.sh
├── trigger.sh
└── upload.sh
```

- `compose.yaml` defines the `api` service and a one-off `init` service under the `setup` profile.
- `deploy.sh` reads runtime secrets, authenticates to ECR, pulls the image, initializes database tables, and starts the API.
- `upload.sh` copies deployment artifacts to S3 under `releases/v1/`.
- `trigger.sh` reads Terraform outputs, invokes SSM Run Command, waits, and reports the result.

```bash
bash deploy/upload.sh
bash deploy/trigger.sh
```

**Observed:** S3 contained `releases/v1/deploy.sh` and `releases/v1/compose.yaml`; SSM deployment returned `Success`.

**Security:** Avoid printing database passwords, JWT signing secrets, or bearer tokens to terminal logs or documentation. ECR Docker login emitted a warning about unencrypted credentials in `/root/.docker/config.json`; improve credential storage for longer-lived environments.

## 5. Bootstrap Failure — Diagnosis and Recovery

**Symptom:** The private EC2 instance appeared online in SSM, but initial preflight commands showed Docker and the AWS CLI were missing and the Docker service was inactive. Cloud-init reported a `scripts_user` failure.

**Investigation:**

- Private subnet had an active default route through a NAT Gateway.
- NAT Gateway was available, and its public subnet routed to the Internet Gateway.
- EC2 application security group allowed outbound HTTPS `443` and PostgreSQL `5432`, but **not outbound HTTP `80`**.
- Ubuntu package repositories needed outbound HTTP access, so `apt-get` could not complete.

**Fix:** Added a Terraform-managed egress rule allowing outbound TCP `80` from the application security group. Terraform planned `1 to add, 0 to change, 0 to destroy`.

Verified repository connectivity with:

```bash
curl -4 -I --connect-timeout 10 http://archive.ubuntu.com/ubuntu/
```

Observed `HTTP/1.1 200 OK`.

Recovered the existing instance by rerunning its cloud-init user-data script through SSM:

```bash
bash /var/lib/cloud/instance/scripts/part-001 > /var/log/inventory-bootstrap-retry.log 2>&1
```

The SSM command finished with `Status: Success` and `ResponseCode: 0`.

**Post-recovery verification:** Docker `29.9.2`, Docker Compose `v5.6.1`, AWS CLI `2.38.5`, and Docker service `active`.

**Lesson:** An SSM-online private instance can still lack the outbound connectivity needed for bootstrap. Diagnose routes, NAT, and security group egress separately.

## 6. Deployment Verification

The deployment SSM command downloaded the release files, logged in to ECR, pulled `v1`, and reported:

```text
Database schema initialized (existing tables left intact).
Container inventory-api-api-1 Started
```

A follow-up `docker ps` confirmed the container was running with `0.0.0.0:8000->8055/tcp`. Uvicorn logs showed `Application startup complete`.

An HTTP check from the EC2 host:

```bash
curl -i --max-time 10 http://127.0.0.1:8000/docs
```

returned `HTTP/1.1 200 OK` and Swagger UI HTML.

**Lesson:** Check container status, process logs, and an actual HTTP response; these establish different levels of confidence.

## 7. Missing ALB — Architecture Gap

**Symptom:** The app worked locally on EC2, but there was no public load balancer endpoint.

```bash
aws elbv2 describe-load-balancers \
  --region us-west-1 \
  --query 'LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' \
  --output table
```

Returned an empty result. The Terraform project had an ALB security group and traffic rules but no actual ALB, listener, target group, or attachment.

**Fix:** Created a reusable `terraform/modules/alb` module, using:

- Internet-facing Application Load Balancer in two public subnets.
- HTTP listener on port `80`.
- Instance target group on port `8000`, initially checking `/docs` for HTTP `200`.
- Attachment registering the existing EC2 instance.

Terraform plan: **`4 to add, 0 to change, 0 to destroy`**. The ALB was deployed without replacing existing EC2 or RDS resources.

**Lesson:** Firewall resources do not create the services they protect. Compare provisioned resources against the intended architecture before declaring completion.

## 8. Public Connectivity and Smoke Tests

The public ALB DNS served FastAPI's Swagger UI at `/docs`. A request to `/` returned FastAPI's expected JSON 404 because no root route was defined.

Verified outcomes:

| Test | Result |
| --- | --- |
| Public `/docs` | Swagger UI rendered |
| Public `/ready` | `{"status":"ready"}` |
| Register test user | HTTP `201 Created`, role `viewer` |
| Log in | HTTP `200 OK`, bearer access token issued |
| Viewer attempts admin-only operation | HTTP `403 Forbidden`, `Admin role required` |

These were targeted smoke tests to establish deployment and basic authorization behavior. Full application CRUD QA was outside the DevOps project scope.

**Important:** The readiness response alone does not prove it checks the database; inspect the route implementation before claiming that.

## 9. Security and Operational Notes

- EC2 is in a private subnet; ALB is the public ingress point.
- ALB → app permitted on TCP `8000`; app → RDS permitted on TCP `5432`.
- Runtime secrets are retrieved from Secrets Manager rather than hardcoded into the Docker image.
- SSM is used for remote commands, avoiding inbound SSH in the deployment path.
- The public ALB is **HTTP-only**. Use disposable credentials and test data; HTTPS is a future improvement.
- Do not commit `.env` files, secret values, JWTs, Terraform state, or local credentials to Git.
- Single EC2 instance, no demonstrated automated rollback, no fully automated CI/CD, and no demonstrated centralized monitoring/alerts.

## 10. Cost, Teardown, and Handoff

The environment may incur ongoing charges for EC2, RDS, NAT Gateway, ALB, storage, and network traffic. Stop using the environment or destroy resources when no longer needed.

```bash
terraform -chdir=terraform/environments/dev plan -destroy
# Review the proposed deletions and database retention requirements.
terraform -chdir=terraform/environments/dev destroy
```

**Do not run destroy without confirming that RDS data may be deleted.** S3 bucket versioning and retained resources may require additional cleanup. Cleanup has **not** been recorded as completed.

### Completion Checklist

- [x] Terraform infrastructure provisioned
- [x] Image built and published to ECR
- [x] S3 + SSM deployment completed
- [x] PostgreSQL schema initialized
- [x] ALB public routing tested
- [x] API readiness and basic auth/RBAC smoke tests passed
- [ ] HTTPS/TLS (deferred)
- [ ] CI/CD pipeline (separate future project)
- [ ] Centralized monitoring, alerting, rollback (future improvements)
- [ ] AWS environment teardown (when lab no longer needed)

**Final status:** Infrastructure provisioning and scripted application deployment completed and verified on October 26, 2026.
