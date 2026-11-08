output "secret_names" {
  description = "Map of environment-variable name => fully-prefixed Secrets Manager secret name."
  value       = local.secret_names
}

output "secret_arns" {
  description = "Map of unprefixed secret key => Secrets Manager secret ARN for every allowlisted secret."
  value       = { for key in values(var.secret_keys) : key => local.managed_secret_arns[key] }
}

output "secret_read_arns" {
  description = "Allowlisted Secrets Manager ARNs for IAM read policies (backend instance role and Lambda role)."
  value       = local.secret_read_arns
}

output "public_environment" {
  description = "Non-secret runtime values exposed under the same environment-variable names used by the backend."
  value = {
    S3_ASSETS_BUCKET                 = var.assets_bucket_name
    SQS_IMAGE_OPTIMIZATION_QUEUE_URL = var.image_optimization_queue_url
  }
}

output "primary_jdbc_url_secret_name" {
  description = "Name of the manually-managed PRIMARY_JDBC_URL secret."
  value       = aws_secretsmanager_secret.primary_jdbc_url.name
}
