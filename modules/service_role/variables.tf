variable "name" {
  description = "Name of the IAM role and instance profile, e.g. vestio-prod-service-role."
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the environment's assets bucket (read/write)."
  type        = string
}

variable "queue_arn" {
  description = "ARN of the environment's image optimizer SQS queue (send message)."
  type        = string
}

variable "secret_read_arns" {
  description = "Secrets Manager secret ARNs the instance may read at boot (the env's prefixed application secrets)."
  type        = list(string)
  default     = []
}

variable "cognito_user_pool_arn" {
  description = "ARN of the environment's Cognito pool. Grants cognito-idp:AdminInitiateAuth (backend /api/auth/login). Empty = no Cognito permission."
  type        = string
  default     = ""
}
