output "lambda_name" {
  description = "Name of the function."
  value       = aws_lambda_function.this.function_name
}

output "lambda_arn" {
  description = "ARN of the function."
  value       = aws_lambda_function.this.arn
}

output "lambda_version" {
  description = "Published version the live alias points at."
  value       = aws_lambda_function.this.version
}

output "lambda_alias_name" {
  description = "Name of the alias the SQS event source mapping invokes."
  value       = aws_lambda_alias.live.name
}

output "lambda_alias_arn" {
  description = "ARN of the live alias."
  value       = aws_lambda_alias.live.arn
}

output "role_arn" {
  description = "ARN of the function's IAM role."
  value       = aws_iam_role.lambda.arn
}
