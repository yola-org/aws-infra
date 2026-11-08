variable "secret_name_prefix" {
  description = "Environment prefix added to every Secrets Manager secret name (e.g. DEV/ or PROD/)."
  type        = string
}

variable "secret_keys" {
  description = <<-EOT
    Single source of truth for the runtime configuration shared by the backend
    and the image-optimizer Lambda.

    Keys are environment-variable names; values are unprefixed Secrets Manager
    keys. The environment prefix (secret_name_prefix) is added automatically.

    Backend: the launch template fetches each value at boot and injects it using
    the environment-variable name.
    Lambda: the map is passed as JSON in APP_SECRET_NAMES and the function
    resolves the values at runtime through its IAM role.
  EOT
  type        = map(string)

  default = {
    S3_ASSETS_BUCKET                 = "S3/ASSETS_BUCKET_NAME"
    SQS_IMAGE_OPTIMIZATION_QUEUE_URL = "SQS/IMAGE_OPTIMIZATION_QUEUE_URL"
    PRIMARY_JDBC_URL                 = "PRIMARY_JDBC_URL"
    COGNITO_CLIENT_ID                = "COGNITO/CLIENT_ID"
    COGNITO_CLIENT_SECRET            = "COGNITO/CLIENT_SECRET"
    COGNITO_ISSUER_URI               = "COGNITO/ISSUER_URI"
    COGNITO_JWK_SET_URI              = "COGNITO/JWK_SET_URI"
    COGNITO_REGION                   = "COGNITO/REGION"
    COGNITO_USER_POOL_ID             = "COGNITO/USER_POOL_ID"
  }

  validation {
    condition     = alltrue([for env_name in keys(var.secret_keys) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", env_name))])
    error_message = "Every secret_keys key must be a valid environment variable name."
  }
}

variable "cognito_secret_arns" {
  description = "Map of unprefixed Cognito secret key => secret ARN, from module.cognito.secret_arns."
  type        = map(string)
}

variable "assets_bucket_name" {
  description = "Assets bucket name stored in S3/ASSETS_BUCKET_NAME."
  type        = string
}

variable "image_optimization_queue_url" {
  description = "Image-optimization queue URL stored in SQS/IMAGE_OPTIMIZATION_QUEUE_URL."
  type        = string
}

variable "secret_recovery_window_in_days" {
  description = "Recovery window for Secrets Manager secrets. Use 0 in non-production environments."
  type        = number
  default     = 7
}
