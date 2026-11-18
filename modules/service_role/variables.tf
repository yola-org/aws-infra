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

variable "realtime_namespace_arns" {
  description = "AppSync Events namespaces this backend may publish to. Empty disables the grant."
  type        = list(string)
  default     = []
}

variable "public_parameter_arns" {
  description = "Exact public Parameter Store parameters the backend may read."
  type        = list(string)
  default     = []
}

variable "public_parameter_path_arn" {
  description = "Shared environment-root parameter path ARN for bulk reads. Empty disables the grant."
  type        = string
  default     = ""
}
