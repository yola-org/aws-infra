output "secret_names" {
  description = "Map of environment-variable name => fully-prefixed Secrets Manager secret name."
  value       = local.secret_names
}

output "secret_arns" {
  description = "Map of unprefixed secret key => Secrets Manager secret ARN for every allowlisted secret."
  value       = { for key in distinct(values(local.all_secrets)) : key => local.all_secret_arns[key] }
}

output "secret_read_arns" {
  description = "Allowlisted Secrets Manager ARNs for IAM read policies (backend instance role)."
  value       = local.secret_read_arns
}

output "public_environment" {
  description = "Non-secret runtime values exposed under the same environment-variable names used by the backend."
  value = {
    S3_ASSETS_BUCKET                 = var.assets_bucket_name
    SQS_IMAGE_OPTIMIZATION_QUEUE_URL = var.image_optimization_queue_url
  }
}
