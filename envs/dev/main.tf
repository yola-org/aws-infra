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

module "cognito" {
  source = "../../modules/cognito"

  name                           = var.cognito_name
  secret_name_prefix             = var.secret_name_prefix
  secret_recovery_window_in_days = 0
}

# Shared runtime configuration: secret names, IAM read ARNs and the
# non-secret values consumed by both the backend and the Lambda.
module "app_config" {
  source = "../../modules/app_config"

  secret_name_prefix           = var.secret_name_prefix
  cognito_secret_arns          = module.cognito.secret_arns
  external_secrets             = var.external_secrets
  assets_bucket_name           = module.storage.bucket
  image_optimization_queue_url = module.queue.queue_url
}

# Dev EC2 service role.
module "service_role" {
  source = "../../modules/service_role"

  name                  = "vestio-dev-service-role"
  bucket_arn            = module.storage.bucket_arn
  queue_arn             = module.queue.queue_arn
  secret_read_arns      = module.app_config.secret_read_arns
  cognito_user_pool_arn = module.cognito.user_pool_arn
}

# Dev image optimizer Lambda. It is published as an immutable version and the
# SQS queue consumes the "live" alias (see modules/image_optimizer_lambda).
module "image_optimizer" {
  source = "../../modules/image_optimizer_lambda"

  name                  = var.image_optimizer_lambda_name
  image_uri             = "${var.image_optimizer_ecr_repository_uri}:${var.image_optimizer_image_tag}"
  bucket_name           = module.storage.bucket
  bucket_arn            = module.storage.bucket_arn
  queue_url             = module.queue.queue_url
  queue_arn             = module.queue.queue_arn
  watermark_text        = var.watermark_text
  environment_variables = module.app_config.public_environment
}
