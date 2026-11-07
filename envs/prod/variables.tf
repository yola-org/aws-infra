
variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ca-central-1"
}

# --- Storage ---------------------------------------------------------------
variable "bucket_name" {
  description = "Name of the prod assets bucket."
  type        = string
  default     = "vestio-assets"
}

variable "cors_allowed_origins" {
  description = "Origins allowed to make cross-origin requests against the bucket."
  type        = list(string)
  default = [
    "https://vestioclothing.com",
    "https://www.vestioclothing.com",
  ]
}

# --- SQS / Lambda (image optimizer) ----------------------------------------
variable "queue_name" {
  description = "Name of the image optimizer SQS queue."
  type        = string
  default     = "vestio-image-optimizer"
}

variable "queue_visibility_timeout_seconds" {
  description = "Visibility timeout of the optimizer queue. Must be >= Lambda timeout."
  type        = number
  default     = 180
}

variable "image_optimizer_lambda_name" {
  description = "Name of the image optimizer Lambda function."
  type        = string
  default     = "vestio-image-optimizer"
}

variable "image_optimizer_image_tag" {
  description = "Tag of the image-optimizer image to deploy. Empty = Lambda not created yet."
  type        = string
  default     = ""
}

variable "watermark_text" {
  description = "Watermark text applied by the image optimizer Lambda."
  type        = string
  default     = "VESTIO"
}

# --- Cognito ---------------------------------------------------------------
variable "cognito_name" {
  description = "Prefix for Cognito resources (pool '<name>-users', client '<name>-backend')."
  type        = string
  default     = "vestio"
}

variable "secret_name_prefix" {
  description = "Prefix for every Secrets Manager secret name. The launch template strips it before injecting env vars."
  type        = string
  default     = "PROD/"
}
# --- vestio-backend ALB + ASG ----------------------------------------------
variable "backend_instance_type" {
  description = "EC2 instance type for vestio-backend instances."
  type        = string
  default     = "t3.small"
}

variable "backend_desired_capacity" {
  description = "Desired ASG size."
  type        = number
  default     = 1
}

variable "backend_min_capacity" {
  description = "Minimum ASG size."
  type        = number
  default     = 1
}

variable "backend_max_capacity" {
  description = "Maximum ASG size."
  type        = number
  default     = 4
}

variable "backend_image_tag" {
  description = "Tag of the backend image to run on instances."
  type        = string
  default     = "latest"
}

variable "backend_vpc_cidr" {
  description = "CIDR block of the vestio-backend VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "backend_health_check_path" {
  description = "ALB health check path."
  type        = string
  default     = "/"
}

variable "backend_health_check_matcher" {
  description = "HTTP codes considered healthy. Widen to 200-403 if Spring Security rejects unauthenticated probes."
  type        = string
  default     = "200-399"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. Empty = HTTP only."
  type        = string
  default     = ""
}

variable "backend_environment" {
  description = "Non-secret environment variables for the backend container (BUCKET_NAME and AWS_REGION are added automatically). Secrets are read from Secrets Manager at boot."
  type        = map(string)
  default     = {}
}

variable "backend_secret_keys" {
  description = <<-EOT
    Backend container environment-variable name => unprefixed Secrets Manager key.
    The environment prefix (secret_name_prefix) is added to each value automatically.
    All Cognito keys are registered by default.
  EOT
  type        = map(string)
  default = {
    COGNITO_CLIENT_ID     = "COGNITO/CLIENT_ID"
    COGNITO_CLIENT_SECRET = "COGNITO/CLIENT_SECRET"
    COGNITO_ISSUER_URI    = "COGNITO/ISSUER_URI"
    COGNITO_JWK_SET_URI   = "COGNITO/JWK_SET_URI"
    COGNITO_REGION        = "COGNITO/REGION"
    COGNITO_USER_POOL_ID  = "COGNITO/USER_POOL_ID"
  }
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
