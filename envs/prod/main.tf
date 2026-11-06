# Cognito values are NOT injected anywhere — the app fetches them from
# Secrets Manager at startup via its instance profile (see modules/backend).
locals {
  backend_environment = merge(
    {
      AWS_REGION  = var.aws_region
      BUCKET_NAME = module.storage.bucket
    },
    var.backend_environment,
  )
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

  name = var.cognito_name
}

# EC2 service role for this environment (S3, SQS, Cognito secret read, Cognito
# admin auth). Also used by the vestio-frontend service when it gets servers.
module "service_role" {
  source = "../../modules/service_role"

  name                  = "vestio-prod-service-role"
  bucket_arn            = module.storage.bucket_arn
  queue_arn             = module.queue.queue_arn
  secret_read_arns      = [module.cognito.client_secret_secret_arn]
  cognito_user_pool_arn = module.cognito.user_pool_arn
}

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

module "backend" {
  source = "../../modules/backend"

  name_prefix                     = "vestio-backend"
  vpc_cidr                        = var.backend_vpc_cidr
  instance_type                   = var.backend_instance_type
  desired_capacity                = var.backend_desired_capacity
  min_capacity                    = var.backend_min_capacity
  max_capacity                    = var.backend_max_capacity
  ecr_repository_url              = var.backend_ecr_repository_uri
  image_tag                       = var.backend_image_tag
  service_role_name               = module.service_role.instance_profile_name
  health_check_path               = var.backend_health_check_path
  health_check_matcher            = var.backend_health_check_matcher
  acm_certificate_arn             = var.acm_certificate_arn
  environment_variables           = local.backend_environment
  environment_variables_sensitive = var.backend_environment_sensitive
}
