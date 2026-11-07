# aws-infra (Vestio)

Terraform-managed AWS infrastructure for Vestio, in **ca-central-1**.

## Repository layout

```
modules/
  storage/                 single S3 bucket + versioning, encryption, CORS, lifecycle, folder placeholders
  queue/                   SQS queue + DLQ (redrive, SSE, long polling)
  registry/                ECR repositories (scan-on-push, lifecycle policies)
  image_optimizer_lambda/  container-image Lambda + IAM + SQS event source mapping
  cognito/                 user pool + app client + per-value Secrets Manager entries (PROD_/DEV_ prefixed)
  service_role/            EC2 service role + instance profile (S3, SQS, prefixed secret read, Cognito admin)
  backend/                 dedicated VPC, ALB, target group, launch template, ASG, user-data (fetches secrets at boot)
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
terraform fmt -check -recursive
terraform validate
terraform plan
```

## Apply policy — plan and validate only

**Never run `terraform apply`** (or `terraform destroy`, `terraform import`, or
`terraform state` mutations) automatically. This applies to local runs,
scripts, AI agents, and any other automation.

The only allowed default flow is:

1. `terraform fmt -check -recursive`
2. `terraform init` / `terraform init -backend=false`
3. `terraform validate`
4. `terraform plan`

Run `terraform apply` **only** when the user explicitly asks for it and confirms
the environment, the plan, and the expected changes. If there is any doubt, stop
and ask first. The GitLab pipeline's own apply jobs are defined separately in
`.gitlab-ci.yml`; this policy covers manual and agent-run commands.

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
- **CI** → secrets are masked, protected CI/CD variables. Runtime secrets are
  not passed through Terraform at all: they live in Secrets Manager and the
  backend launch template reads them at boot via the instance profile.
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

Optional CI/CD variable: `TF_VAR_image_optimizer_image_uri`.

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

### Config is stored in Secrets Manager — one string secret per value

No JSON blobs. Each env creates eight Secrets Manager **string secrets**. The name
is `<PREFIX><SECRET_KEY>`, where the prefix is `PROD/` for prod and `DEV/`
for dev:

| Secret name (prod / dev) | Container env var | Spring property |
|---|---|---|
| `PROD/COGNITO/CLIENT_ID` / `DEV/COGNITO/CLIENT_ID` | `COGNITO_CLIENT_ID` | `cognito.client-id` |
| `PROD/COGNITO/CLIENT_SECRET` / `DEV/COGNITO/CLIENT_SECRET` | `COGNITO_CLIENT_SECRET` | `cognito.client-secret` |
| `PROD/COGNITO/USER_POOL_ID` / `DEV/COGNITO/USER_POOL_ID` | `COGNITO_USER_POOL_ID` | `cognito.user-pool-id` |
| `PROD/COGNITO/REGION` / `DEV/COGNITO/REGION` | `COGNITO_REGION` | `cognito.region` |
| `PROD/COGNITO/ISSUER_URI` / `DEV/COGNITO/ISSUER_URI` | `COGNITO_ISSUER_URI` | `spring.security.oauth2.resourceserver.jwt.issuer-uri` |
| `PROD/COGNITO/JWK_SET_URI` / `DEV/COGNITO/JWK_SET_URI` | `COGNITO_JWK_SET_URI` | `spring.security.oauth2.resourceserver.jwt.jwk-set-uri` |
| `PROD/ASSETS/BUCKET_NAME` / `DEV/ASSETS/BUCKET_NAME` | `S3_ASSETS_BUCKET` | — |
| `PROD/SQS/IMAGE_OPTIMIZATION_QUEUE_URL` / `DEV/SQS/IMAGE_OPTIMIZATION_QUEUE_URL` | `SQS_IMAGE_OPTIMIZATION_QUEUE_URL` | — |

The backend launch template receives only the **secret names** and their target
container environment-variable names (an explicit allowlist built from
`backend_secret_keys`). At boot, user-data calls `secretsmanager:GetSecretValue`
for each one through the instance profile, writes the configured environment
variable names to `/etc/vestio-backend.env` (mode `600`), and starts the container with
`docker run --env-file`. Secret values never appear in Terraform, the launch
template, tfvars, CI variables, `docker run` arguments, or cloud-init logs.

The instance role is granted `secretsmanager:GetSecretValue` +
`DescribeSecret` on exactly those eight ARNs — **no `ListSecrets`** permission.

Both prod and dev deployments get the unprefixed env vars from the launch
template; the app never calls Secrets Manager on those servers. Local
development uses the same unprefixed `COGNITO_*` names: a local-only Spring
resolver (`LocalCognitoSecretsEnvironmentPostProcessor`) reads any missing value
from the matching `DEV_*` secret using the developer's default AWS credentials.

Spring Boot sees clean keys, so `application.yml` can use either relaxed
binding or explicit placeholders:

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: ${COGNITO_ISSUER_URI}
          jwk-set-uri: ${COGNITO_JWK_SET_URI}
cognito:
  region:         ${COGNITO_REGION}
  client-id:      ${COGNITO_CLIENT_ID}
  client-secret:  ${COGNITO_CLIENT_SECRET}
  user-pool-id:   ${COGNITO_USER_POOL_ID}
```

Dev's six secrets and IAM permissions are created, but dev runs no servers yet.
Outputs: `cognito_user_pool_id`, `cognito_client_id`, `cognito_issuer_uri`,
`cognito_jwks_uri`, `cognito_secret_names`, `cognito_secret_arns`.

Notes:
- Run locally: `./gradlew bootRun` — the `local` profile resolves the six
  `DEV_*` secrets automatically into `COGNITO_*` via
  `LocalCognitoSecretsEnvironmentPostProcessor`. Your AWS identity needs
  `secretsmanager:GetSecretValue` on those six secrets, plus the pool's
  `AdminCreateUser`/`AdminSetUserPassword` for the seeded-users sync. Exported
  `COGNITO_*` values take precedence. Dev servers use the launch template, like
  prod.
- The old single-JSON secret (`vestio/cognito-client-secret`) is no longer used
  by the backend.
- Pool sign-up auto-verifies email via Cognito's default email sender; for real
  deliverability switch `email_configuration` to SES once your domain is verified.
- Set `deletion_protection = "ACTIVE"` on the pool input when prod is stable.
- Secret values still live in the Terraform state — keep state in the encrypted,
  locked S3 bucket and never commit it.

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
- **Secrets:** `backend_environment` is for non-secret values only. Runtime
  secrets are fetched from Secrets Manager at boot (see the Cognito section
  above). Register what gets injected with `backend_secret_keys` (defined in
  both env roots) as `CONTAINER_ENV_NAME = "SECRET_KEY"` — the six Cognito
  mappings plus `S3_ASSETS_BUCKET` and `SQS_IMAGE_OPTIMIZATION_QUEUE_URL` are
  already there. The environment prefix is added to each secret
  key automatically, and the same map drives both the launch template and the
  instance-role read permissions. Dev has no ASG yet, so there it currently
  drives IAM only. Never
  add secret values to tfvars, CI variables, or the launch template.

## Folder placeholders

S3 has no real folders; zero-byte `static/`, `listings/`, `users/` objects are created
only so the prefixes render in the console. Disable with
`create_folder_placeholders = false` on the storage module if undesired.

## Cost notes

- Buckets block all public access; serve assets via CloudFront + OAC if needed.
- Noncurrent object versions expire after 90 days (`noncurrent_version_expiration_days`).
- ASG defaults: 1–4 × `t3.small`, CPU target tracking at 60%.
- Dev has **no** EC2/ALB — it costs only S3/SQS/ECR/(optional Lambda).
