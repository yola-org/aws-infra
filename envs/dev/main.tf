
locals {
  # Single registration point for the credentials the dev backend may consume.
  # The keys come from the cognito module. Dev has no ASG yet, so this drives IAM.
  backend_secret_arns = module.cognito.secret_arns

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
