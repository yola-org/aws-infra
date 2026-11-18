resource "aws_iam_role" "logs" {
  name = "${var.name}-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "appsync.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "logs" {
  name = "${var.name}-logs"
  role = aws_iam_role.logs.id

  # The API ID is not known until the API (which needs this role) exists.
  # Restrict the bootstrap grant to AppSync log groups in this account/region.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/appsync/apis/*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/appsync/apis/${aws_appsync_api.this.api_id}"
  retention_in_days = var.log_retention_in_days
}

# Backend publishing uses HTTP. These metrics include malformed requests,
# authorization failures, throttling, and server failures on that endpoint.
resource "aws_cloudwatch_metric_alarm" "http_errors" {
  for_each = toset(["4XXError", "5XXError"])

  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = "AppSync HTTP publishing errors; inspect backend outbox retries and AppSync logs."
  namespace           = "AWS/AppSync"
  metric_name         = each.key
  dimensions          = { EventAPIId = aws_appsync_api.this.api_id }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "subscription_errors" {
  for_each = local.namespaces

  alarm_name        = "${var.name}-${each.key}-subscription-errors"
  alarm_description = "Repeated subscription rejections; inspect client auth and private channel paths."
  namespace         = "AWS/AppSync"
  metric_name       = "SubscribeClientError"
  dimensions = {
    EventAPIId           = aws_appsync_api.this.api_id
    ChannelNamespaceName = each.key
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
}
