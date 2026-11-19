output "bucket_name" {
  description = "Name of the dev assets bucket (static/, listings/, users/ prefixes)."
  value       = module.storage.bucket
}

output "bucket_arn" {
  description = "ARN of the dev assets bucket."
  value       = module.storage.bucket_arn
}

output "image_optimizer_queue_url" {
  description = "URL of the dev image optimizer SQS queue."
  value       = module.queue.queue_url
}

output "image_optimizer_queue_arn" {
  description = "ARN of the dev image optimizer SQS queue."
  value       = module.queue.queue_arn
}

output "image_optimizer_dlq_url" {
  description = "URL of the dev image optimizer dead-letter queue."
  value       = module.queue.dlq_url
}

output "image_optimizer_lambda_name" {
  description = "Name of the dev image optimizer Lambda."
  value       = module.image_optimizer.lambda_name
}

output "service_role_name" {
  description = "Name of the dev EC2 service role (instance profile)."
  value       = module.service_role.role_name
}

output "service_role_arn" {
  description = "ARN of the dev EC2 service role."
  value       = module.service_role.role_arn
}

output "service_role_instance_profile_name" {
  description = "Name of the dev EC2 instance profile."
  value       = module.service_role.instance_profile_name
}

output "cognito_user_pool_id" {
  description = "Dev Cognito user pool ID."
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Dev Cognito app client ID."
  value       = module.cognito.client_id
}

output "cognito_issuer_uri" {
  description = "Dev Cognito OIDC issuer URI."
  value       = module.cognito.issuer_uri
}

output "cognito_secret_names" {
  description = "Dev Secrets Manager secret names holding the individual Cognito values (DEV_ prefix)."
  value       = module.cognito.secret_names
}

output "cognito_secret_arns" {
  description = "Map of unprefixed env-var key => dev Secrets Manager secret ARN."
  value       = module.cognito.secret_arns
}

output "realtime_api_id" {
  description = "Realtime api id."
  value       = module.realtime.api_id
}

output "realtime_api_arn" {
  description = "Realtime api arn."
  value       = module.realtime.api_arn
}

output "realtime_http_endpoint" {
  description = "Realtime http endpoint."
  value       = module.realtime.http_endpoint
}

output "realtime_websocket_endpoint" {
  description = "Realtime websocket endpoint."
  value       = module.realtime.websocket_endpoint
}

output "realtime_namespace_arns" {
  description = "Realtime namespace arns."
  value       = module.realtime.namespace_arns
}

output "realtime_backend_environment" {
  description = "Realtime backend environment."
  value       = module.realtime.backend_environment
}

output "public_parameter_names" {
  description = "Shared infrastructure Parameter Store names (legacy backend group)."
  value       = module.public_parameters.names
}

output "public_parameter_paths" {
  description = "Shared infrastructure configuration paths (legacy backend group)."
  value       = module.public_parameters.paths
}
