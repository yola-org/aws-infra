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

# Cognito configuration is stored as a single JSON secret so the backend can
# fetch everything at startup (default AWS credentials chain). The secret is
# created by this module after the pool/client — nothing is baked into the
# image/launch template and no env vars are used.
locals {
  client_secret_secret_name = coalesce(var.client_secret_secret_name, "${var.name}/cognito-client-secret")
  jwks_uri                  = "${local.issuer_uri}/.well-known/jwks.json"
}

resource "aws_secretsmanager_secret" "client_secret" {
  name                    = local.client_secret_secret_name
  description             = "Cognito app configuration for ${var.name}-backend (clientId, clientSecret, userPoolId, issuerUri, jwkSetUri, region)"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "client_secret" {
  secret_id = aws_secretsmanager_secret.client_secret.id

  secret_string = jsonencode({
    clientId     = aws_cognito_user_pool_client.app.id
    clientSecret = aws_cognito_user_pool_client.app.client_secret
    userPoolId   = aws_cognito_user_pool.this.id
    issuerUri    = local.issuer_uri
    jwkSetUri    = local.jwks_uri
    region       = data.aws_region.current.name
  })
}
