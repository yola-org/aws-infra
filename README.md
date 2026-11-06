# aws-infra (Vestio)

Terraform-managed AWS infrastructure for Vestio, in **ca-central-1**.

## Repository layout

```
modules/
  storage/                 single S3 bucket + versioning, encryption, CORS, lifecycle, folder placeholders
  queue/                   SQS queue + DLQ (redrive, SSE, long polling)
  registry/                ECR repositories (scan-on-push, lifecycle policies)
  image_optimizer_lambda/  container-image Lambda + IAM + SQS event source mapping
  cognito/                 user pool + app client + Secrets Manager entry (full config JSON)
  service_role/            EC2 service role + instance profile (S3, SQS, Cognito secret read, Cognito admin)
  backend/                 dedicated VPC, ALB, target group, launch template, ASG, user-data
envs/
  dev/                     dev environment root (bucket + queue + dev Lambda + dev ECR + dev service role — NO ALB/ASG)
  prod/                    prod environment root (everything + prod service role + vestio-backend ALB/ASG)
.gitlab-ci.yml             validate/plan/apply pipelines (admin key from CI/CD variables)
```

## Environments — how dev and prod differ

| | dev | prod |
|---|---|---|
| Bucket | `vestio-dev-assets` | `vestio-assets` |
| EC2 service role | `vestio-dev-service-role` (instance profile) | `vestio-prod-service-role` (instance profile) |
| Cognito | `vestio-dev-users` pool + client | `vestio-users` pool + client |
| Prefixes | `static/`, `listings/`, `users/` (placeholder folders created) | same |
| SQS | `vestio-dev-image-optimizer` (+ DLQ) | `vestio-image-optimizer` (+ DLQ) |
| Lambda | `vestio-dev-image-optimizer` | `vestio-image-optimizer` |
| ECR | `vestio/dev-vestio-backend`, `vestio/dev-image-optimizer` | `vestio/vestio-backend`, `vestio/image-optimizer` |
| ALB / ASG / EC2 | **none** | `vestio-backend-alb` + `vestio-backend-asg` (1–4 × t3.small) |
| Watermark | `VESTIO-DEV` | `VESTIO` |
| State key | `dev/terraform.tfstate` | `prod/terraform.tfstate` |

Branching model: **`dev` and `prod` branches, environment separation by directory.**
Each branch contains the same `envs/` + `modules/` tree; the branch only selects
which environment's pipeline runs — merges never copy code between branches.
Workflow: branch off `dev`/`prod` → open an MR **targeting the env branch** → CI runs
`terraform:validate` → after the MR is accepted and merged, the post-merge pipeline on
the env branch applies it (dev automatically, prod manually). Applies never run on merge
requests, and MRs never receive cloud credentials (protected CI variables are only
available on the protected `dev`/`prod` branches). Recommended: protect both branches
(MR approval required, no direct pushes) and protect the `prod` CI environment.

## Usage

Terraform manages **nothing for CI** — the pipeline receives an AWS admin user's
credentials from protected CI/CD variables (see below). Per environment:

```bash
cd envs/prod        # or envs/dev
terraform init
terraform plan
terraform apply    # or merge to the env branch and let CI apply it
```

No `terraform.tfvars` is required — all non-secret defaults live in each env's
`variables.tf`. Optional overrides: copy `terraform.tfvars.example` (gitignored) and adjust.

## State backend

Each env uses its own S3 state key (`dev/terraform.tfstate`, `prod/terraform.tfstate`)
in a shared bucket `vestio-terraform-state` with native S3 locking (`use_lockfile`,
Terraform ≥ 1.10). Create the bucket once, manually, before the first init:

```bash
aws s3api create-bucket --bucket vestio-terraform-state \
  --region ca-central-1 --create-bucket-configuration LocationConstraint=ca-central-1
aws s3api put-bucket-versioning --bucket vestio-terraform-state \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket vestio-terraform-state \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

If you don't want remote state yet, comment out `backend.tf` and use local state
(don't commit it — it's gitignored).

## Secrets policy — no placeholders in Git

Do **not** commit placeholder secrets to be sed-replaced in CI. Instead:

- **Non-secret config** → baked into `envs/<env>/variables.tf` (env-specific defaults).
- **CI** → secrets are masked, protected CI/CD variables, consumed as `TF_VAR_*`
  (e.g. `TF_VAR_backend_environment_sensitive` = JSON map of sensitive container env
  vars). Terraform picks them up automatically.
- **Local runs** → untracked `terraform.tfvars` (gitignored) or shell exports.
- If you already run **HashiCorp Vault**, prefer it for secret env vars over CI
  variables: authenticate the job to Vault (AppRole/JWT auth) and `vault read` the
  values in `before_script`, exporting them as `TF_VAR_*`.

## CI: an existing AWS admin user — nothing created in Terraform

The pipeline uses the credentials of an **already-existing AWS admin user**
(created and managed outside this repo — e.g. via console/IAM Identity Center).
Terraform manages **nothing** for CI; it only builds the dev/prod infrastructure.

GitLab **Settings → CI/CD → Variables** (both **masked + protected**; protected
refs = `dev` and `prod` branches only):

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Job behaviour:

| Pipeline trigger | Jobs that get cloud credentials |
|---|---|
| MR / feature branch | none — `terraform:validate` only |
| push/merge to `dev` | dev plan (+ automatic apply) |
| push/merge to `prod` | prod plan (+ **manual** apply) |

**Protection model**: the variables are masked + protected and only the `dev` and
`prod` branches are protected, so the admin key never reaches MRs or feature
branches. Branch safety is enforced by pipeline rules and environment protection,
not IAM — keep `prod` apply manual and protect the `prod` branch/environment
(authorized appliers only). Rotate this key periodically in AWS and update the two
CI variables (prefer IAM Identity Center short-lived tokens if your plan supports
them — same variables, no storage of static keys at all).

Optional CI/CD variables: `TF_VAR_backend_environment_sensitive`,
`TF_VAR_image_optimizer_image_uri`.

## Cognito (both environments)

Each env creates an **email-based** Cognito user pool (`vestio-dev-users` /
`vestio-users`) and an app client (`generate_secret = true`, SRP + password + refresh +
**admin-password** auth flows — the backend's `/api/auth/login` uses `ADMIN_NO_SRP_AUTH` —
access token 1h / ID token 24h / refresh 30d, min password length 12 with
all character classes, verified-email recovery, MFA off by default).

The backend calls Cognito itself: `signup` → `SignUp` (public API, no IAM permission
needed, SECRET_HASH derived from the client secret), `login` → `AdminInitiateAuth`
(ADMIN_NO_SRP_AUTH). For the latter, the prod instance role gets
`cognito-idp:AdminInitiateAuth` scoped to the pool — without it login returns
AccessDenied. The app client allows `ALLOW_ADMIN_USER_PASSWORD_AUTH` for the same reason.
JWT validation for all other endpoints uses only the public JWKS — no credentials.

### Config is stored in Secrets Manager — the only source of Cognito data

Tenant-specific Cognito values for each environment are stored in ONE **Secrets
Manager JSON secret** — Terraform creates it after the pool/client:

```json
{
  "clientId": "…", "clientSecret": "…", "userPoolId": "…",
  "issuerUri": "…", "jwkSetUri": "…", "region": "ca-central-1"
}
```

Secret names: `vestio/cognito-client-secret` (prod) and
`vestio-dev/cognito-client-secret` (dev).

The backend at startup (`CognitoEnvironmentPostProcessor`) fetches the secret
using the **default AWS credentials chain** — on EC2 that's the
`vestio-prod-service-role` instance profile (allowed `secretsmanager:GetSecretValue`
+ `DescribeSecret` on exactly that one secret, plus `cognito-idp:AdminInitiateAuth`
on the pool). Locally it's your AWS profile.
**No Cognito environment variables exist anywhere** — nothing is baked into the
image, the launch template, or tfvars.

```yaml
spring.security.oauth2.resourceserver.jwt.issuer-uri:   ${cognito.issuer-uri}
spring.security.oauth2.resourceserver.jwt.jwk-set-uri:  ${cognito.jwk-set-uri}
cognito:
  region:         ${cognito.region}
  client-id:      ${cognito.client-id}
  client-secret:  ${cognito.client-secret}
  user-pool-id:   ${cognito.user-pool-id}
```

Dev's pool/client/secret are created but wired to nothing (dev runs no servers).
Outputs: `cognito_user_pool_id`, `cognito_client_id`, `cognito_issuer_uri`,
`cognito_jwks_uri`, `cognito_client_secret_secret_id`.

Notes:
- Run locally: `AWS_PROFILE=vestio-dev ./gradlew bootRun` — your profile needs only
  `secretsmanager:GetSecretValue` on `vestio-dev/cognito-client-secret` (+ the pool's
  `AdminCreateUser`/`AdminSetUserPassword` for the seeded-users sync).
- Pool sign-up auto-verifies email via Cognito's default email sender; for real
  deliverability switch `email_configuration` to SES once your domain is verified.
- Set `deletion_protection = "ACTIVE"` on the pool input when prod is stable.
- The client secret and pool config also live in the Terraform state — keep state
  in the encrypted, locked S3 bucket and never commit it.

## The image-optimizer Lambda is intentionally decoupled

The Lambda code repo does **not** exist yet. Neither env creates the function until
you pass an image URI:

1. `terraform apply` creates everything except the Lambda and its event source
   mapping (a log group is always created).
2. Once the image-optimizer repo exists, build & push its Docker image to the
   `vestio/image-optimizer` (prod) / `vestio/dev-image-optimizer` (dev) ECR repo.
3. Set `image_optimizer_image_uri` (CI variable `TF_VAR_image_optimizer_image_uri`,
   or untracked `terraform.tfvars`) and re-apply.

The Lambda receives SQS messages, downloads source images from the bucket's
`listings/` / `users/` prefixes, optimizes them, stamps the watermark
(`WATERMARK_TEXT`, default `VESTIO`), and writes results back. Configuration is
passed via env vars: `BUCKET_NAME`, `STATIC_PREFIX`, `LISTINGS_PREFIX`,
`USERS_PREFIX`, `SQS_QUEUE_URL`, `WATERMARK_TEXT`.

## vestio-backend ASG (prod only)

Instances boot with Docker, authenticate to ECR, pull
`vestio/vestio-backend:<backend_image_tag>`, and run it on port **80 → 8080**,
logging to `/var/log/vestio-backend`.

- **Health check:** path `/`, matcher `200-399`. vestio-backend has no Spring
  Actuator yet; if Spring Security rejects unauthenticated probes, set
  `backend_health_check_matcher = "200-403"` (untracked tfvars or `TF_VAR_*`), or add
  Actuator and point `backend_health_check_path` at `/actuator/health`.
- **HTTPS:** set `acm_certificate_arn` to enable the 443 listener and redirect 80→443.
- **Secrets:** `backend_environment` (non-secret) and `backend_environment_sensitive`
  (sensitive) are merged into the container env. If you use
  `SPRING_DATASOURCE_URL` etc. via env, pass them as `TF_VAR_backend_environment_sensitive`
  from CI — never commit them.

## Folder placeholders

S3 has no real folders; zero-byte `static/`, `listings/`, `users/` objects are created
only so the prefixes render in the console. Disable with
`create_folder_placeholders = false` on the storage module if undesired.

## Cost notes

- Buckets block all public access; serve assets via CloudFront + OAC if needed.
- Noncurrent object versions expire after 90 days (`noncurrent_version_expiration_days`).
- ASG defaults: 1–4 × `t3.small`, CPU target tracking at 60%.
- Dev has **no** EC2/ALB — it costs only S3/SQS/ECR/(optional Lambda).
