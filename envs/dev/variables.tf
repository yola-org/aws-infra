variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ca-central-1"
}

# --- Storage (single bucket, static/ listings/ users/ prefixes) -----------
variable "bucket_name" {
  description = "Name of the dev assets bucket."
  type        = string
  default     = "vestio-dev-assets"
}

variable "cors_allowed_origins" {
  description = "Origins allowed to make cross-origin requests against the bucket."
  type        = list(string)
  default = [
    "http://localhost:3000",
    "https://dev.vestioclothing.com",
  ]
}

# --- SQS / Lambda (image optimizer) ----------------------------------------
variable "queue_name" {
  description = "Name of the dev image optimizer SQS queue."
  type        = string
  default     = "vestio-dev-image-optimizer"
}

variable "queue_visibility_timeout_seconds" {
  description = "Visibility timeout of the optimizer queue. Must be >= Lambda timeout."
  type        = number
  default     = 180
}

variable "image_optimizer_lambda_name" {
  description = "Name of the dev image optimizer Lambda function."
  type        = string
  default     = "vestio-dev-image-optimizer"
}

variable "image_optimizer_image_uri" {
  description = "Full ECR image URI (with tag) for the Lambda. Empty = Lambda not created yet."
  type        = string
  default     = ""
}

variable "watermark_text" {
  description = "Watermark text applied by the image optimizer Lambda."
  type        = string
  default     = "VESTIO-DEV"
}

# --- Cognito ---------------------------------------------------------------
variable "cognito_name" {
  description = "Prefix for Cognito resources (pool \"<name>-users\", client \"<name>-backend\")."
  type        = string
  default     = "vestio-dev"
}

# --- ECR -------------------------------------------------------------------
variable "ecr_repositories" {
  description = "ECR repository names to create for dev."
  type        = list(string)
  default = [
    "vestio/dev-vestio-backend",
    "vestio/dev-image-optimizer",
  ]
}

variable "ecr_image_retention_count" {
  description = "Number of tagged images to keep per repository."
  type        = number
  default     = 10
}
