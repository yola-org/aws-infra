locals {
  issuer_uri = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.this.id}"
}

output "user_pool_id" {
  description = "Cognito user pool ID (e.g. ca-central-1_xxxxxxxxx)."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "Cognito user pool ARN."
  value       = aws_cognito_user_pool.this.arn
}

output "client_id" {
  description = "App client ID."
  value       = aws_cognito_user_pool_client.app.id
}

output "client_secret" {
  description = "App client secret (sensitive; also stored in the Secrets Manager config secret)."
  value       = aws_cognito_user_pool_client.app.client_secret
  sensitive   = true
}

output "issuer_uri" {
  description = "OIDC issuer URI for the user pool."
  value       = local.issuer_uri
}

output "jwks_uri" {
  description = "JWKS URI used by Spring Security to validate JWTs."
  value       = "${local.issuer_uri}/.well-known/jwks.json"
}

output "client_secret_secret_id" {
  description = "Secrets Manager secret ID holding the full Cognito config JSON (read by the app at startup via instance profile)."
  value       = aws_secretsmanager_secret.client_secret.id
}

output "client_secret_secret_arn" {
  description = "Secrets Manager secret ARN holding the Cognito config JSON."
  value       = aws_secretsmanager_secret.client_secret.arn
}
