variable "name" {
  description = "Environment-specific AppSync Events API name."
  type        = string
}

variable "cognito_user_pool_id" {
  description = "User pool allowed to connect and subscribe."
  type        = string
}

variable "cognito_client_id" {
  description = "Only tokens issued for this app client are accepted."
  type        = string
}

variable "log_retention_in_days" {
  description = "Retention of error logs."
  type        = number
  default     = 7
}

variable "alarm_actions" {
  description = "Optional existing SNS topic ARNs for alarm and recovery notifications. Empty means CloudWatch alarms only."
  type        = list(string)
  default     = []
}
