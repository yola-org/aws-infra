output "bucket" {
  description = "Name of the assets bucket."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "ARN of the assets bucket."
  value       = aws_s3_bucket.this.arn
}
