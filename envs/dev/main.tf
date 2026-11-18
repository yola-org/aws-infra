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

  name                      = "vestio-dev-service-role"
  bucket_arn                = module.storage.bucket_arn
  queue_arn                 = module.queue.queue_arn
  secret_read_arns          = module.app_config.secret_read_arns
  cognito_user_pool_arn     = module.cognito.user_pool_arn
  realtime_namespace_arns   = values(module.realtime.namespace_arns)
  public_parameter_arns     = values(module.public_parameters.arns.backend)
  public_parameter_path_arn = module.public_parameters.path_arns.backend
}

# Dev image optimizer Lambda. It is published as an immutable version and the
# SQS queue consumes the "live" alias (see modules/image_optimizer_lambda).
module "image_optimizer" {
  source = "../../modules/image_optimizer_lambda"

  name                   = var.image_optimizer_lambda_name
  deployment_environment = "dev"
  image_uri              = "${var.image_optimizer_ecr_repository_uri}:${var.image_optimizer_image_tag}"
  bucket_name            = module.storage.bucket
  bucket_arn             = module.storage.bucket_arn
  queue_url              = module.queue.queue_url
  queue_arn              = module.queue.queue_arn
  watermark_text         = var.watermark_text
  environment_variables  = module.app_config.public_environment
  primary_jdbc_secret    = module.app_config.primary_jdbc_secret
}

module "realtime" {
  source = "../../modules/realtime"

  name                 = "vestio-dev-realtime"
  cognito_user_pool_id = module.cognito.user_pool_id
  cognito_client_id    = module.cognito.client_id
  alarm_actions        = var.realtime_alarm_actions
}

module "public_parameters" {
  source = "../../modules/public_parameters"

  environment = "dev"
  secret_environment_names = setsubtract(
    toset(keys(module.app_config.secret_names)),
    toset(keys(module.cognito.public_environment)),
  )
  services = {
    backend = merge(
      module.cognito.public_environment,
      merge(
        module.app_config.public_environment,
        module.realtime.backend_environment,
        { AWS_REGION = var.aws_region, BUCKET_NAME = module.storage.bucket },
        var.backend_environment,
      ),
    )
    image-optimizer = module.image_optimizer.public_environment
    frontend = {
      NEXT_PUBLIC_APPSYNC_EVENTS_HTTP_ENDPOINT      = module.realtime.http_endpoint
      NEXT_PUBLIC_APPSYNC_EVENTS_WEBSOCKET_ENDPOINT = module.realtime.websocket_endpoint
      NEXT_PUBLIC_APPSYNC_EVENTS_REGION             = var.aws_region
      NEXT_PUBLIC_COGNITO_USER_POOL_ID              = module.cognito.user_pool_id
      NEXT_PUBLIC_COGNITO_CLIENT_ID                 = module.cognito.client_id
    }
  }
}
