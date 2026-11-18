data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  namespaces = toset(["chat", "notifications"])
}

resource "aws_appsync_api" "this" {
  name = var.name

  event_config {
    auth_provider {
      auth_type = "AMAZON_COGNITO_USER_POOLS"
      cognito_config {
        user_pool_id        = var.cognito_user_pool_id
        aws_region          = data.aws_region.current.region
        app_id_client_regex = "^${var.cognito_client_id}$"
      }
    }

    auth_provider {
      auth_type = "AWS_IAM"
    }

    connection_auth_mode {
      auth_type = "AMAZON_COGNITO_USER_POOLS"
    }

    default_publish_auth_mode {
      auth_type = "AWS_IAM"
    }

    default_subscribe_auth_mode {
      auth_type = "AMAZON_COGNITO_USER_POOLS"
    }

    log_config {
      cloudwatch_logs_role_arn = aws_iam_role.logs.arn
      log_level                = "ERROR"
    }
  }

  depends_on = [aws_iam_role_policy.logs]
}

resource "aws_appsync_channel_namespace" "this" {
  for_each = local.namespaces

  api_id        = aws_appsync_api.this.api_id
  name          = each.key
  code_handlers = file("${path.module}/handlers/private-subscription.js")

  publish_auth_mode {
    auth_type = "AWS_IAM"
  }

  subscribe_auth_mode {
    auth_type = "AMAZON_COGNITO_USER_POOLS"
  }

  depends_on = [aws_cloudwatch_log_group.this]
}
