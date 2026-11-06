
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

  name = var.cognito_name
}

# Dev EC2 service role.
module "service_role" {
  source = "../../modules/service_role"

  name                  = "vestio-dev-service-role"
  bucket_arn            = module.storage.bucket_arn
  queue_arn             = module.queue.queue_arn
  secret_read_arns      = [module.cognito.client_secret_secret_arn]
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
