locals {
  # ARNs of every secret that can be referenced by secret_keys. Cognito owns its
  # own secrets; the remaining values are managed here.
  managed_secret_arns = merge(
    var.cognito_secret_arns,
    {
      "S3/ASSETS_BUCKET_NAME"            = aws_secretsmanager_secret.assets_bucket_name.arn
      "SQS/IMAGE_OPTIMIZATION_QUEUE_URL" = aws_secretsmanager_secret.image_optimization_queue_url.arn
      "PRIMARY_JDBC_URL"                 = aws_secretsmanager_secret.primary_jdbc_url.arn
    },
  )

  # Environment-variable name => fully-prefixed Secrets Manager secret name.
  secret_names = {
    for env_name, key in var.secret_keys : env_name => "${var.secret_name_prefix}${key}"
  }

  # Same allowlist, expressed as ARNs for IAM policies.
  secret_read_arns = [
    for key in values(var.secret_keys) : local.managed_secret_arns[key]
  ]
}

check "secret_keys_have_arns" {
  assert {
    condition = alltrue([
      for key in values(var.secret_keys) : contains(keys(local.managed_secret_arns), key)
    ])
    error_message = "Every secret_keys value must resolve to a Cognito or app_config-managed secret ARN."
  }
}

resource "aws_secretsmanager_secret" "assets_bucket_name" {
  name                    = "${var.secret_name_prefix}S3/ASSETS_BUCKET_NAME"
  description             = "Assets bucket name for the Vestio backend and image optimizer"
  recovery_window_in_days = var.secret_recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "assets_bucket_name" {
  secret_id     = aws_secretsmanager_secret.assets_bucket_name.id
  secret_string = var.assets_bucket_name
}

resource "aws_secretsmanager_secret" "image_optimization_queue_url" {
  name                    = "${var.secret_name_prefix}SQS/IMAGE_OPTIMIZATION_QUEUE_URL"
  description             = "Image optimization SQS queue URL for the Vestio backend and image optimizer"
  recovery_window_in_days = var.secret_recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "image_optimization_queue_url" {
  secret_id     = aws_secretsmanager_secret.image_optimization_queue_url.id
  secret_string = var.image_optimization_queue_url
}

# No aws_secretsmanager_secret_version is managed here on purpose: the JDBC URL
# is set manually in Secrets Manager and must never pass through Terraform.
resource "aws_secretsmanager_secret" "primary_jdbc_url" {
  name                    = "${var.secret_name_prefix}PRIMARY_JDBC_URL"
  description             = "Primary database JDBC URL (value set manually in Secrets Manager)"
  recovery_window_in_days = var.secret_recovery_window_in_days
}
