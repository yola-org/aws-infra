locals {
  issuer_uri = "https://cognito-idp.${data.aws_region.current.region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
}

output "user_pool_id" {
  description = "Cognito user pool ID (e.g. ca-central-1_xxxxxxxxx)."
  value       = aws_cognito_user_pool.this.id
}

output "public_environment" {
  description = "Non-secret Cognito runtime identifiers. The client secret is deliberately excluded."
  value = {
    COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.app.id
    COGNITO_USER_POOL_ID = aws_cognito_user_pool.this.id
    COGNITO_REGION       = data.aws_region.current.region
    COGNITO_ISSUER_URI   = local.issuer_uri
    COGNITO_JWK_SET_URI  = "${local.issuer_uri}/.well-known/jwks.json"
  }
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
  description = "App client secret (sensitive; also stored in Secrets Manager as <prefix>COGNITO_CLIENT_SECRET)."
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

output "secret_names" {
  description = "Sorted Secrets Manager secret names holding the individual Cognito values (env-prefixed)."
  value       = [for k in sort(keys(local.cognito_secrets)) : aws_secretsmanager_secret.this[k].name]
}

output "secret_arns" {
  description = "Map of unprefixed env-var key => Secrets Manager secret ARN for the Cognito values."
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.arn }
}
