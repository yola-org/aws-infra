resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_in_days
}

resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = var.image_uri

  # Every code/config change creates an immutable version. The "live" alias
  # below points at the version the SQS event source mapping invokes.
  publish = true

  timeout     = var.timeout_seconds
  memory_size = var.memory_size

  ephemeral_storage {
    size = var.ephemeral_storage_mb
  }

  # The function receives non-secret configuration only. Secrets are not passed
  # to the Lambda; values that must stay private live in the backend's env file.
  environment {
    variables = merge(
      var.environment_variables,
      {
        APP_ENV         = var.deployment_environment
        BUCKET_NAME     = var.bucket_name
        STATIC_PREFIX   = "static/"
        LISTINGS_PREFIX = "listings/"
        USERS_PREFIX    = "users/"
        SQS_QUEUE_URL   = var.queue_url
        WATERMARK_TEXT  = var.watermark_text
      },
    )
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Version currently consumed by the SQS event source mapping."
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn                   = var.queue_arn
  function_name                      = aws_lambda_alias.live.arn
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = 5
  enabled                            = true

  scaling_config {
    maximum_concurrency = var.max_concurrency
  }

  function_response_types = ["ReportBatchItemFailures"]
}

moved {
  from = aws_lambda_function.this[0]
  to   = aws_lambda_function.this
}

moved {
  from = aws_lambda_alias.live[0]
  to   = aws_lambda_alias.live
}

moved {
  from = aws_lambda_event_source_mapping.sqs[0]
  to   = aws_lambda_event_source_mapping.sqs
}
