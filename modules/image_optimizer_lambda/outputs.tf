output "lambda_name" {
  description = "Name of the function (null when image_uri is not set)."
  value       = local.enabled ? aws_lambda_function.this[0].function_name : null
}

output "lambda_arn" {
  description = "ARN of the function (null when image_uri is not set)."
  value       = local.enabled ? aws_lambda_function.this[0].arn : null
}

output "enabled" {
  description = "Whether the Lambda and its event source mapping were created."
  value       = local.enabled
}

output "role_arn" {
  description = "ARN of the function's IAM role."
  value       = aws_iam_role.lambda.arn
}
