variable "secret_name_prefix" {
  description = "Environment prefix added to every Secrets Manager secret name (e.g. DEV/ or PROD/)."
  type        = string
}

variable "secret_keys" {
  description = <<-EOT
    Source of truth for secrets CREATED by Terraform, keyed by the container
    environment-variable name. Values are unprefixed Secrets Manager keys; the
    environment prefix (secret_name_prefix) is added automatically.

    Secrets that already exist outside Terraform go in external_secrets instead.

    Backend: the launch template fetches each value at boot and injects it using
    the environment-variable name.
  EOT
  type        = map(string)

  default = {
    # created in modules/cognito/main.tf -> aws_secretsmanager_secret.this[each.key]
    COGNITO_CLIENT_ID     = "COGNITO/CLIENT_ID"
    COGNITO_CLIENT_SECRET = "COGNITO/CLIENT_SECRET"
    COGNITO_USER_POOL_ID  = "COGNITO/USER_POOL_ID"
    COGNITO_REGION        = "COGNITO/REGION"
    COGNITO_ISSUER_URI    = "COGNITO/ISSUER_URI"
    COGNITO_JWK_SET_URI   = "COGNITO/JWK_SET_URI"
  }

  validation {
    condition     = alltrue([for env_name in keys(var.secret_keys) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", env_name))])
    error_message = "Every secret_keys key must be a valid environment variable name."
  }
}

variable "external_secrets" {
  description = <<-EOT
    Secrets that already exist in Secrets Manager, keyed by the container
    environment-variable name. Values are unprefixed Secrets Manager keys; the
    environment prefix (secret_name_prefix) is added automatically.

    Each referenced secret is looked up at plan time, so a missing secret fails
    the plan instead of booting with an empty value. Provide this map from the
    environment root (terraform.tfvars or TF_VAR_external_secrets).
  EOT
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for env_name in keys(var.external_secrets) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", env_name))])
    error_message = "Every external_secrets key must be a valid environment variable name."
  }

  validation {
    condition     = alltrue([for key in values(var.external_secrets) : length(trimspace(key)) > 0])
    error_message = "Every external_secrets value must be a non-empty Secrets Manager key."
  }
}

variable "cognito_secret_arns" {
  description = "Map of unprefixed Cognito secret key => secret ARN, from module.cognito.secret_arns."
  type        = map(string)
}

variable "assets_bucket_name" {
  description = "Assets bucket name exposed as the non-secret S3_ASSETS_BUCKET environment variable."
  type        = string
}

variable "image_optimization_queue_url" {
  description = "Image-optimization queue URL exposed as the non-secret SQS_IMAGE_OPTIMIZATION_QUEUE_URL environment variable."
  type        = string
}
