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

variable "image_optimizer_image_tag" {
  description = "Tag of the image-optimizer image to deploy. Empty = Lambda not created yet."
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

variable "secret_name_prefix" {
  description = "Prefix for every Secrets Manager secret name. The launch template strips it before injecting env vars."
  type        = string
  default     = "DEV/"
}

# --- Shared ECR repositories (manually managed) ---------------------------

variable "backend_ecr_repository_uri" {
  description = "Full URI of the shared backend ECR repository."
  type        = string
  default     = "187692046882.dkr.ecr.ca-central-1.amazonaws.com/vestio/backend"
}

variable "image_optimizer_ecr_repository_uri" {
  description = "Full URI of the shared image optimizer ECR repository."
  type        = string
  default     = "187692046882.dkr.ecr.ca-central-1.amazonaws.com/vestio/image-optimizer"
}
