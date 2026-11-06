output "bucket_name" {
  description = "Name of the prod assets bucket (static/, listings/, users/ prefixes)."
  value       = module.storage.bucket
}

output "bucket_arn" {
  description = "ARN of the prod assets bucket."
  value       = module.storage.bucket_arn
}

output "image_optimizer_queue_url" {
  description = "URL of the image optimizer SQS queue."
  value       = module.queue.queue_url
}

output "image_optimizer_queue_arn" {
  description = "ARN of the image optimizer SQS queue."
  value       = module.queue.queue_arn
}

output "image_optimizer_dlq_url" {
  description = "URL of the image optimizer dead-letter queue."
  value       = module.queue.dlq_url
}

output "ecr_repository_urls" {
  description = "URLs of the created ECR repositories."
  value       = module.registry.repository_urls
}

output "image_optimizer_lambda_name" {
  description = "Name of the image optimizer Lambda (null until image_optimizer_image_uri is set)."
  value       = module.image_optimizer.lambda_name
}

output "backend_alb_dns_name" {
  description = "Public DNS name of the vestio-backend ALB."
  value       = module.backend.alb_dns_name
}

output "cognito_user_pool_id" {
  description = "Prod Cognito user pool ID."
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Prod Cognito app client ID."
  value       = module.cognito.client_id
}

output "cognito_issuer_uri" {
  description = "Prod Cognito OIDC issuer URI (also embedded in the Secrets Manager config secret)."
  value       = module.cognito.issuer_uri
}

output "cognito_jwks_uri" {
  description = "Prod Cognito JWKS URI (also embedded in the Secrets Manager config secret)."
  value       = module.cognito.jwks_uri
}

output "cognito_client_secret_secret_id" {
  description = "Secrets Manager secret ID holding the prod Cognito configuration JSON (read by the app at startup via instance profile)."
  value       = module.cognito.client_secret_secret_id
}

output "service_role_name" {
  description = "Name of the prod EC2 service role (instance profile)."
  value       = module.service_role.role_name
}

output "service_role_arn" {
  description = "ARN of the prod EC2 service role."
  value       = module.service_role.role_arn
}

output "service_role_instance_profile_name" {
  description = "Name of the prod EC2 instance profile."
  value       = module.service_role.instance_profile_name
}

output "backend_asg_name" {
  description = "Name of the vestio-backend Auto Scaling Group."
  value       = module.backend.asg_name
}

output "vpc_id" {
  description = "ID of the vestio-backend VPC."
  value       = module.backend.vpc_id
}
