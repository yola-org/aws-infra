variable "name" {
  description = "Name of the Lambda function (also used for the IAM role and log group)."
  type        = string
}

variable "deployment_environment" {
  description = "Deployment environment exposed to the Lambda as APP_ENV."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "prod"], var.deployment_environment)
    error_message = "deployment_environment must be dev or prod."
  }
}

variable "image_uri" {
  description = "Full ECR image URI (including tag) for the function. Required; plan fails if it is missing or empty."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.image_uri)) > 0
    error_message = "image_uri must be a non-empty ECR image URI, including the tag."
  }
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
