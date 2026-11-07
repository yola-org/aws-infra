data "aws_region" "current" {}

resource "aws_cognito_user_pool" "this" {
  name = "${var.name}-users"

  # Email-based sign-in
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  deletion_protection = var.deletion_protection
  mfa_configuration   = var.mfa_configuration

  password_policy {
    minimum_length    = var.password_min_length
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 5
      max_length = 254
    }
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  # Keep payloads small; extend with custom attributes as needed.
  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }
}

resource "aws_cognito_user_pool_client" "app" {
  name         = "${var.name}-backend"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret               = true
  prevent_user_existence_errors = "ENABLED"

  # ADMIN_NO_SRP_AUTH (used by the backend's /api/auth/login) requires
  # ALLOW_ADMIN_USER_PASSWORD_AUTH on the app client.
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  access_token_validity  = var.access_token_validity_hours
  id_token_validity      = var.id_token_validity_hours
  refresh_token_validity = var.refresh_token_validity_days
}

# Each Cognito value is stored as its own Secrets Manager string secret. The
# name is prefixed with the environment (PROD_ / DEV_) and the rest of the name
# is the exact Spring Boot environment-variable key. The backend launch template
# fetches these secrets at boot, strips the prefix, and injects them as env vars.
locals {
  jwks_uri = "${local.issuer_uri}/.well-known/jwks.json"

  cognito_secrets = {
    COGNITO_CLIENT_ID     = aws_cognito_user_pool_client.app.id
    COGNITO_CLIENT_SECRET = aws_cognito_user_pool_client.app.client_secret
    COGNITO_USER_POOL_ID  = aws_cognito_user_pool.this.id
    COGNITO_REGION        = data.aws_region.current.name
    COGNITO_ISSUER_URI    = local.issuer_uri
    COGNITO_JWK_SET_URI   = local.jwks_uri
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.cognito_secrets

  name                    = "${var.secret_name_prefix}${each.key}"
  description             = "Cognito ${each.key} for ${var.name}-backend"
  recovery_window_in_days = var.secret_recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = local.cognito_secrets

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = each.value
}
