mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "ca-central-1" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_appsync_api" {
    defaults = {
      api_id  = "test-api"
      api_arn = "arn:aws:appsync:ca-central-1:123456789012:apis/test-api"
      dns = {
        HTTP     = "test.appsync-api.ca-central-1.amazonaws.com"
        REALTIME = "test.appsync-realtime-api.ca-central-1.amazonaws.com"
      }
    }
  }
}

variables {
  name                 = "vestio-test-realtime"
  cognito_user_pool_id = "ca-central-1_test"
  cognito_client_id    = "testclient123"
}

run "private_realtime_configuration" {
  command = plan

  assert {
    condition = (
      aws_appsync_api.this.event_config[0].connection_auth_mode[0].auth_type == "AMAZON_COGNITO_USER_POOLS" &&
      aws_appsync_api.this.event_config[0].default_subscribe_auth_mode[0].auth_type == "AMAZON_COGNITO_USER_POOLS" &&
      aws_appsync_api.this.event_config[0].default_publish_auth_mode[0].auth_type == "AWS_IAM"
    )
    error_message = "Only Cognito clients may connect/subscribe; only IAM publishers may publish."
  }

  assert {
    condition = alltrue([
      for ns in aws_appsync_channel_namespace.this :
      ns.publish_auth_mode[0].auth_type == "AWS_IAM" &&
      ns.subscribe_auth_mode[0].auth_type == "AMAZON_COGNITO_USER_POOLS" &&
      ns.code_handlers == file("${path.module}/handlers/private-subscription.js")
    ]) && toset(keys(aws_appsync_channel_namespace.this)) == toset(["chat", "notifications"])
    error_message = "Both namespaces must enforce private subscriptions and IAM-only publishing."
  }

  assert {
    condition = (
      aws_appsync_api.this.event_config[0].auth_provider[0].cognito_config[0].app_id_client_regex == "^testclient123$" &&
      aws_appsync_api.this.event_config[0].log_config[0].log_level == "ERROR" &&
      aws_cloudwatch_log_group.this.retention_in_days == 7
    )
    error_message = "Restrict the app client and retain only seven days of error logs."
  }
}
