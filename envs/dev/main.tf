
locals {
  # Single registration point for the configuration the dev backend may consume.
  # Dev has no ASG yet, so this currently drives IAM.
  backend_secret_arns = merge(
    module.cognito.secret_arns,
    {
      "S3/ASSETS_BUCKET_NAME"               = aws_secretsmanager_secret.assets_bucket_name.arn
      "SQS/IMAGE_OPTIMIZATION_QUEUE_URL" = aws_secretsmanager_secret.image_optimization_queue_url.arn
    },
  )

  backend_secret_names = {
    for env_name, key in var.backend_secret_keys : env_name => "${var.secret_name_prefix}${key}"
  }

  backend_secret_read_arns = [
    for key in values(var.backend_secret_keys) : local.backend_secret_arns[key]
  ]
}

check "backend_secret_keys_have_arns" {
  assert {
    condition = alltrue([
      for key in values(var.backend_secret_keys) : contains(keys(local.backend_secret_arns), key)
    ])
    error_message = "Every backend_secret_keys value must exist in module.cognito.secret_arns."
  }
}

module "storage" {
  source = "../../modules/storage"

  bucket_name          = var.bucket_name
  cors_allowed_origins = var.cors_allowed_origins
}

module "queue" {
  source = "../../modules/queue"

  name                       = var.queue_name
  visibility_timeout_seconds = var.queue_visibility_timeout_seconds
}

# These configuration values are prepared for the future dev backend and are
# included in the dev service role's allowlisted secret-read permissions.
resource "aws_secretsmanager_secret" "assets_bucket_name" {
  name                    = "${var.secret_name_prefix}S3/ASSETS_BUCKET_NAME"
  description             = "Assets bucket name for vestio-dev backend"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "assets_bucket_name" {
  secret_id     = aws_secretsmanager_secret.assets_bucket_name.id
  secret_string = module.storage.bucket
}

resource "aws_secretsmanager_secret" "image_optimization_queue_url" {
  name                    = "${var.secret_name_prefix}SQS/IMAGE_OPTIMIZATION_QUEUE_URL"
  description             = "Image optimization SQS queue URL for vestio-dev backend"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "image_optimization_queue_url" {
  secret_id     = aws_secretsmanager_secret.image_optimization_queue_url.id
  secret_string = module.queue.queue_url
}

module "cognito" {
  source = "../../modules/cognito"

  name                           = var.cognito_name
  secret_name_prefix             = var.secret_name_prefix
  secret_recovery_window_in_days = 0
}

# Dev EC2 service role.
module "service_role" {
  source = "../../modules/service_role"

  name                  = "vestio-dev-service-role"
  bucket_arn            = module.storage.bucket_arn
  queue_arn             = module.queue.queue_arn
  secret_read_arns      = local.backend_secret_read_arns
  cognito_user_pool_arn = module.cognito.user_pool_arn
}

# Dev image optimizer Lambda.
module "image_optimizer" {
  source = "../../modules/image_optimizer_lambda"

  name           = var.image_optimizer_lambda_name
  image_uri      = var.image_optimizer_image_tag == "" ? "" : "${var.image_optimizer_ecr_repository_uri}:${var.image_optimizer_image_tag}"
  bucket_name    = module.storage.bucket
  bucket_arn     = module.storage.bucket_arn
  queue_url      = module.queue.queue_url
  queue_arn      = module.queue.queue_arn
  watermark_text = var.watermark_text
}
