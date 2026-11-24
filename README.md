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
  realtime/                AppSync Events for private chat/notification channels, logs, and alarms
  public_parameters/       Standard SSM String parameters for shared infrastructure values
  app_config/              shared secret maps (created + external), public env, IAM read ARNs (backend)
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
| AppSync Events | `vestio-dev-realtime` | `vestio-prod-realtime` |
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

`image_optimizer_image_tag` is required (`terraform.tfvars` or `TF_VAR_image_optimizer_image_tag`). Plan fails if it is missing or empty.

## Cognito (both environments)

Each env creates an **email-based** Cognito user pool (`vestio-dev-users` /
`vestio-users`) and an app client (`generate_secret = true`, SRP + password + refresh +
**admin-password** auth flows — the backend's `/api/auth/login` uses `ADMIN_NO_SRP_AUTH` —
access token 1h / ID token 24h / refresh 30d, min password length 12 with
all character classes, admin-only recovery, MFA off by default).

The backend calls Cognito itself: `signup` → `SignUp` (public API, no IAM permission
needed, SECRET_HASH derived from the client secret), `login` → `AdminInitiateAuth`
(ADMIN_NO_SRP_AUTH). For the latter, the prod instance role gets
`cognito-idp:AdminInitiateAuth` scoped to the pool — without it login returns
AccessDenied. The app client allows `ALLOW_ADMIN_USER_PASSWORD_AUTH` for the same reason.
JWT validation for all other endpoints uses only the public JWKS — no credentials.

### Config: secrets in Secrets Manager, non-secrets as public env

There are two kinds of runtime configuration, with no overlap:

- **Public env** — non-sensitive identifiers passed to the backend and Lambda as
  plain environment variables: `S3_ASSETS_BUCKET`,
  `SQS_IMAGE_OPTIMIZATION_QUEUE_URL` (plus the Lambda's `BUCKET_NAME` /
  `SQS_QUEUE_URL`). These are not secrets; IAM protects the resources.
- **Secrets** — values that must stay private, read from Secrets Manager.

Secrets come from two maps in `modules/app_config`, keyed by the container
environment-variable name:

- `secret_keys` — secrets **created by Terraform** (the six Cognito values).
- `external_secrets` — secrets that **already exist** in Secrets Manager,
  supplied per environment (`PRIMARY_JDBC_URL` by default, plus anything else
  you add). Each one is looked up at plan time, so a missing secret fails the
  plan instead of booting with an empty value.

The name is `<PREFIX><SECRET_KEY>`, where the prefix is `PROD/` for prod and
`DEV/` for dev:

| Secret name (prod / dev) | Container env var | Created by |
|---|---|---|
| `PROD/COGNITO/CLIENT_ID` / `DEV/COGNITO/CLIENT_ID` | `COGNITO_CLIENT_ID` | `modules/cognito` |
| `PROD/COGNITO/CLIENT_SECRET` / `DEV/COGNITO/CLIENT_SECRET` | `COGNITO_CLIENT_SECRET` | `modules/cognito` |
| `PROD/COGNITO/USER_POOL_ID` / `DEV/COGNITO/USER_POOL_ID` | `COGNITO_USER_POOL_ID` | `modules/cognito` |
| `PROD/COGNITO/REGION` / `DEV/COGNITO/REGION` | `COGNITO_REGION` | `modules/cognito` |
| `PROD/COGNITO/ISSUER_URI` / `DEV/COGNITO/ISSUER_URI` | `COGNITO_ISSUER_URI` | `modules/cognito` |
| `PROD/COGNITO/JWK_SET_URI` / `DEV/COGNITO/JWK_SET_URI` | `COGNITO_JWK_SET_URI` | `modules/cognito` |
| `PROD/PRIMARY_JDBC_URL` / `DEV/PRIMARY_JDBC_URL` | `PRIMARY_JDBC_URL` | external (pre-existing) |

Create the JDBC secret and its value in Secrets Manager for each environment
(`PROD/PRIMARY_JDBC_URL` or `DEV/PRIMARY_JDBC_URL`). Terraform looks up the
secret metadata. The services fetch the JDBC URL at runtime.

The canonical env-var => secret-key maps live once in `modules/app_config`, not
in each environment root. They drive two things:

1. the backend launch template (secret names and target container env var names),
2. the backend IAM read allowlist.

Terraform passes the primary JDBC secret ARN to the image optimizer. The Lambda reads the value from Secrets Manager at runtime.

At boot, user-data calls `secretsmanager:GetSecretValue` for each allowlisted
secret through the instance profile, writes the configured environment variable
names to `/etc/vestio-backend.env` (mode `600`), and starts the container with
`docker run --env-file`. Secret values never appear in Terraform, the launch
template, tfvars, CI variables, `docker run` arguments, or cloud-init logs.

The instance role is granted `secretsmanager:GetSecretValue` +
`DescribeSecret` on exactly those ARNs — **no `ListSecrets`** permission.

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

Dev's six Cognito secrets (plus the app secrets above) and IAM permissions are created, but dev runs no servers yet.
Outputs: `cognito_user_pool_id`, `cognito_client_id`, `cognito_issuer_uri`,
`cognito_jwks_uri`, `cognito_secret_names`, `cognito_secret_arns`.

Notes:
- Run locally: `./gradlew bootRun` — the `local` profile resolves the six
  `DEV_*` secrets automatically into `COGNITO_*` via
  `LocalCognitoSecretsEnvironmentPostProcessor`. Your AWS identity needs
  `secretsmanager:GetSecretValue` on those six Cognito secrets, plus the pool's
  `AdminCreateUser`/`AdminSetUserPassword` for the seeded-users sync. Exported
  `COGNITO_*` values take precedence. Dev servers use the launch template, like
  prod.
- The old single-JSON secret (`vestio/cognito-client-secret`) is no longer used
  by the backend.
- Pool sign-up email and password-recovery email are disabled in Cognito. The
  backend sends confirmation PINs and welcome emails through Resend.
- Set `deletion_protection = "ACTIVE"` on the pool input when prod is stable.
- Secret values still live in the Terraform state — keep state in the encrypted,
  locked S3 bucket and never commit it.

## The image-optimizer Lambda

`image_optimizer_image_tag` has no default. Set it in tfvars (or
`TF_VAR_image_optimizer_image_tag`) to the tag already pushed to ECR. Plan fails
when the variable is missing, null, or empty, and the function is always created
from `<image_optimizer_ecr_repository_uri>:<image_optimizer_image_tag>`.

### Releases: versions + `live` alias (blue-green flip)

The function is published (`publish = true`), so every image/config change creates
an immutable Lambda version. The SQS event source mapping does **not** invoke
`$LATEST`; it invokes the **`live` alias**, which points at the current version:

- `terraform apply` with a new image: new version published → alias moved → SQS
  starts delivering to the new version.
- Rollback = move `live` back to the previous version (alias update in place, a
  few seconds). Messages buffered in SQS are not lost.
- In-flight batches finish on the version they started on; new batches use the alias.
- `module.image_optimizer.lambda_version` / `lambda_alias_arn` expose the current
  version and alias for CI and dashboards; CloudWatch also records the alias as a
  metric dimension so blue (old) vs green (new) error rates can be compared.

Published versions are never deleted automatically — prune old ones once no alias
points at them.

The Lambda consumes listing image events from SQS, writes WebP renditions to S3, and updates listing status in PostgreSQL once the renditions are ready.

The existing Lambda execution role has `secretsmanager:GetSecretValue` on its environment's JDBC secret. For a customer-managed KMS key, it also gets `kms:Decrypt` on that key, scoped to the secret's encryption context. The KMS key policy must allow the role to use this grant. The Lambda must be able to reach the PostgreSQL endpoint from its runtime network.

## vestio-backend ASG (prod only)

Instances boot with Docker, authenticate to ECR, pull
`vestio/vestio-backend:<backend_image_tag>`, and run it on port **80 → 8080**,
logging to `/var/log/vestio-backend`.

- **Health check:** path `/`, matcher `200-399`. vestio-backend has no Spring
  Actuator yet; if Spring Security rejects unauthenticated probes, set
  `backend_health_check_matcher = "200-403"` (untracked tfvars or `TF_VAR_*`), or add
  Actuator and point `backend_health_check_path` at `/actuator/health`.
- **HTTPS:** set `acm_certificate_arn` to enable the 443 listener and redirect 80→443.
- **Secrets:** `backend_environment` is for non-secret values only (it is merged
  with `public_environment`). Runtime secrets are fetched from Secrets Manager at
  boot (see the secrets section above). The `CONTAINER_ENV_NAME = "SECRET_KEY"`
  maps live once in `modules/app_config`: `secret_keys` for Terraform-created
  secrets and `external_secrets` for pre-existing ones (supplied per environment
  via tfvars). The environment prefix is added to each secret key automatically,
  and the same maps drive the launch template and the instance-role read
  permissions. Dev has no ASG yet, so there they drive IAM only. Never add
  secret values to tfvars, CI variables, or the launch template.

## Folder placeholders

S3 has no real folders; zero-byte `static/`, `listings/`, `users/` objects are created
only so the prefixes render in the console. Disable with
`create_folder_placeholders = false` on the storage module if undesired.

## Cost notes

- Listing WebP images and thumbnails are publicly readable through the assets bucket policy. Public ACLs are blocked.
- Noncurrent object versions expire after 90 days (`noncurrent_version_expiration_days`).
- ASG defaults: 1–4 × `t3.small`, CPU target tracking at 60%.
- Dev has **no** EC2/ALB; realtime adds usage-based AppSync and CloudWatch costs.

## Chat and live notifications — AppSync Events

`modules/realtime` creates a dedicated Event API in each environment:
`vestio-dev-realtime` and `vestio-prod-realtime`, in the configured AWS region.
It creates the `chat` and `notifications` namespaces, error-level CloudWatch
logging with seven-day retention, and four CloudWatch alarms per environment.
There are no additional chat servers, Redis clusters, Lambda authorizers, or
connection tables. AppSync operations, connection minutes, transfer, logs, and
alarms are usage-billed; alarms can be a meaningful part of a small dev bill.

### Authorization and channels

- Connect and subscribe with a token from that environment's existing Cognito
  pool and app client. Never expose the app client secret to the browser.
- Each user subscribes to `/chat/{cognitoSub}` and
  `/notifications/{cognitoSub}` over one WebSocket connection. Use the Cognito
  `sub`, not the application's database user ID unless they are identical.
- The shared `onSubscribe` handler allows only an exact match to the authenticated
  user's channel. Other users, namespace subscriptions, wildcard subscriptions,
  and extra path segments are rejected.
- Only IAM-authenticated publishers may publish. The existing backend role gets
  `appsync:EventPublish` on its environment's two namespace ARNs, with no
  connect/subscribe or cross-environment grants. Privileged account IAM principals
  can still publish if their own policies grant access.
- Backend publishers use signed HTTPS requests (SigV4 service `appsync`), not
  WebSockets. No API keys or long-lived AWS keys are added.

### Configuration

Terraform exposes `realtime_api_id`, `realtime_api_arn`,
`realtime_http_endpoint`, `realtime_websocket_endpoint`,
`realtime_namespace_arns`, and `realtime_backend_environment` in both environments.
The HTTP endpoint includes `/event`; the WebSocket endpoint includes
`/event/realtime`. The frontend must use the AppSync Events protocol/client,
including its authentication handshake, rather than a generic chat protocol.

Prod's backend launch template receives `APPSYNC_EVENTS_HTTP_ENDPOINT` and
`APPSYNC_EVENTS_REGION` as non-secret environment variables. Dev still has no
backend servers: use `realtime_backend_environment` to configure local/dev
publishing and a suitably scoped developer role. Do not assume local credentials
automatically have the EC2 service role's permissions.

Set `realtime_alarm_actions` to existing SNS topic ARNs to deliver alarm and
recovery notifications. The default empty list creates visible CloudWatch alarms
without sending notifications. HTTP `4XXError`/`5XXError` alarms detect one error
within five minutes; each namespace's `SubscribeClientError` alarm detects ten
rejections within five minutes. These use the Event API dimensions
`EventAPIId` and, for subscriptions, `ChannelNamespaceName`.

Handlers do not log message bodies or tokens. Keep logging at `ERROR`; AWS may
include request/error context in service logs, so treat log access as sensitive.

### Application work and delivery contract

This repository provisions transport and access control. The backend and frontend
still need their chat/notification integration:

1. Authorize the action and recipients in the backend.
2. Save messages/notifications and an outbox record in one PostgreSQL transaction.
3. Have a backend worker publish committed outbox entries and retry failures,
   including per-event failures returned in an otherwise successful HTTP response.
4. Include stable event IDs; clients deduplicate retries and fetch missed updates
   and unread counts over the existing HTTP API after reconnecting.
5. Monitor outbox age and terminal failures in the backend. Transport alarms cannot
   detect a worker that has stopped publishing.

AppSync Events does not provide chat history or offline notification replay.
Notifications while the app is closed need Web Push/mobile push as a separate
delivery path. Attachments remain in S3; publish references rather than file data.

### Validation and rollout

AppSync Events resources require the AWS provider upgrade from 5.100.0 to the
pinned 6.12.0. Review both complete environment plans for provider migration
changes as well as the realtime additions. Backend environment changes update the
prod launch template; existing instances need the normal backend rollout to pick
up the new variables.

```bash
terraform fmt -check -recursive
terraform -chdir=envs/dev init -backend=false -input=false
terraform -chdir=envs/dev validate
terraform -chdir=envs/prod init -backend=false -input=false
terraform -chdir=envs/prod validate
node --test modules/realtime/tests/private-subscription.test.mjs
terraform -chdir=modules/realtime init -backend=false -input=false
terraform -chdir=modules/realtime test
```

For deployment review, initialize each environment's configured backend and run
`terraform plan` with its real configuration. Use the existing manual approval
policy before any apply. After an approved dev deployment, verify own-channel
subscriptions, rejection of other-user/wildcard subscriptions and browser
publishing, IAM publishing to both namespaces, and reconnect recovery before
promoting to prod. Local JavaScript tests verify authorization decisions, not the
AWS-hosted runtime or end-to-end delivery.


## Public runtime configuration — Parameter Store

Parameter Store contains only shared, non-secret infrastructure values as
Standard `String` parameters under `/DEV/` and `/PROD/`, matching the uppercase
environment prefixes used by Secrets Manager (for example, `/DEV/AWS_REGION`).
Parameter names have no `vestio` prefix:

- `AWS_REGION`, `S3_ASSETS_BUCKET`, and `SQS_IMAGE_OPTIMIZATION_QUEUE_URL`
- Cognito public identifiers, region, issuer URI, and JWK set URI
- `APPSYNC_EVENTS_HTTP_ENDPOINT` and `APPSYNC_EVENTS_REGION`

Do not store `NEXT_*` variables or service-specific settings in Parameter Store.
Backend overrides, `BUCKET_NAME`, and `LOGGING_FILE_NAME` are passed directly to
the backend container. Lambda settings (including prefixes, watermark, `APP_ENV`,
and JDBC secret metadata) are passed directly through its environment block.
Frontend builds must receive their `NEXT_*` settings through their deployment
configuration; existing Cognito and realtime Terraform outputs supply the
infrastructure values needed to configure those builds.

The module allows only the shared keys listed above. Terraform outputs
`public_parameter_names` and `public_parameter_paths` retain the legacy `backend`
group for compatibility. Terraform resource addresses stay the same, but shared
parameters are renamed from `/vestio/dev/<ENV_VAR>` and `/vestio/prod/<ENV_VAR>`
to `/DEV/<ENV_VAR>` and `/PROD/<ENV_VAR>`. This replaces the existing parameters
and updates the backend role’s read permissions. The next approved apply also
removes previously managed frontend parameters, optimizer parameters, and
backend-specific parameters. Review these changes in each environment’s plan
before applying, and update external readers to use the new paths.

The backend role can read the shared parameters individually or by path. Local
users need an AWS identity with read access to the environment root. Known
credential keys and names configured as secrets are rejected. Cognito's legacy
Secrets Manager entries remain for compatibility; secrets such as the Cognito
client secret and JDBC URL stay in Secrets Manager.

To load shared infrastructure defaults for a local backend, authenticate AWS CLI
and run this helper from the backend working directory:

```bash
python3 /home/youssef-laarossi/Documents/aws-infra/scripts/run-with-public-config.py \
  --environment dev --service backend --region ca-central-1 --profile YOUR_PROFILE \
  -- ./gradlew bootRun
```

The helper reads direct `String` parameters, preserves caller overrides, and
passes values to the child process without printing them or evaluating shell
exports. It fails if the path is empty or cannot be read. Supply service-specific
settings separately and keep the existing secret resolution for
`COGNITO_CLIENT_SECRET`, `PRIMARY_JDBC_URL`, and other secrets. The helper does not
support frontend or optimizer service maps.

Terraform changes require a reviewed plan and explicit environment approval
before apply. The local helper and validation tests perform no SSM writes.

### Public profile images

User images reuse the existing environment assets bucket (`vestio-dev-assets`
or `vestio-assets`), under `users/{userId}/profile/{randomUuid}.{jpg|png|webp}`.
The storage bucket policy grants public `GetObject` only for these image paths,
in addition to the existing listing-image paths. Other user assets remain private.
The backend service role already has S3 read/write/delete permission. Profile
uploads are synchronous backend-to-S3 writes and do not publish to the optimizer
queue or introduce bucket notifications.

Generate and review plans for each environment before deployment, with the
required `image_optimizer_image_tag` configured. Review any unrelated optimizer
changes separately and follow the existing apply policy.

### Backend-owned account confirmation

The backend sends confirmation PINs and welcome messages through Resend. Cognito
has no automatic verified attributes and account recovery is `admin_only`, so
signup and forgot-password do not send Cognito email. Email MFA is not enabled.
The backend validates its latest stored PIN before calling `AdminConfirmSignUp`
and `AdminUpdateUserAttributes` with `email_verified=true`. Its role also permits
`AdminGetUser` to recover a partially completed confirmation. These actions are
scoped to the environment's user pool. Any future password recovery must use a
backend-owned flow rather than Cognito's `ForgotPassword` email delivery.
