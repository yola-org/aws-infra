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

output "ecr_repository_urls" {
  description = "URLs of the created dev ECR repositories."
  value       = module.registry.repository_urls
}

output "image_optimizer_lambda_name" {
  description = "Name of the dev image optimizer Lambda (null until image_optimizer_image_uri is set)."
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

output "cognito_client_secret_secret_id" {
  description = "Secrets Manager secret ID holding the dev Cognito configuration JSON (read by the app at startup)."
  value       = module.cognito.client_secret_secret_id
}
