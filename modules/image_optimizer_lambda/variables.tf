variable "name" {
  description = "Name of the Lambda function (also used for the IAM role and log group)."
  type        = string
}

variable "image_uri" {
  description = <<-EOT
    Full ECR image URI (including tag) for the function, e.g.
    123456789012.dkr.ecr.ca-central-1.amazonaws.com/vestio/image-optimizer:latest

    Leave empty (default) to skip creating the Lambda and its event source mapping.
    The Lambda code repo does not exist yet; once it does, push the image and set this.
  EOT
  type        = string
  default     = ""
}

variable "timeout_seconds" {
  description = "Lambda timeout in seconds. The triggering SQS visibility timeout must be >= this."
  type        = number
  default     = 120
}

variable "memory_size" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 1024
}

variable "ephemeral_storage_mb" {
  description = "Lambda ephemeral storage (/tmp) in MB."
  type        = number
  default     = 2048
}

variable "batch_size" {
  description = "Number of SQS messages per Lambda invocation."
  type        = number
  default     = 1
}

variable "max_concurrency" {
  description = "Maximum concurrent executions triggered by the queue."
  type        = number
  default     = 10
}

variable "watermark_text" {
  description = "Watermark text applied by the function."
  type        = string
  default     = "VESTIO"
}

variable "log_retention_in_days" {
  description = "CloudWatch Logs retention for the function's log group."
  type        = number
  default     = 14
}

variable "bucket_name" {
  description = "Name of the assets bucket (static/, listings/, users/ prefixes)."
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the assets bucket."
  type        = string
}

variable "queue_url" {
  description = "URL of the SQS queue passed to the function as SQS_QUEUE_URL."
  type        = string
}

variable "queue_arn" {
  description = "ARN of the SQS queue used for the event source mapping and IAM policy."
  type        = string
}

variable "environment_variables" {
  description = "Additional non-secret environment variables for the function."
  type        = map(string)
  default     = {}
}

variable "secret_names" {
  description = <<-EOT
    Map of environment-variable name => fully-prefixed Secrets Manager secret name.
    It is passed to the function as JSON in APP_SECRET_NAMES so the function can
    resolve the values at runtime through its IAM role.
  EOT
  type        = map(string)
  default     = {}
}

variable "secret_read_arns" {
  description = "Secrets Manager ARNs the function is allowed to read (GET + DESCRIBE)."
  type        = list(string)
  default     = []
}
