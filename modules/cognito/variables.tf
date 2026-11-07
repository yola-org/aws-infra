variable "name" {
  description = "Name prefix for Cognito resources, e.g. \"vestio\" (prod) or \"vestio-dev\" (dev)."
  type        = string
}

variable "password_min_length" {
  description = "Minimum password length."
  type        = number
  default     = 12
}

variable "mfa_configuration" {
  description = "MFA configuration for the user pool: OFF, ON or OPTIONAL."
  type        = string
  default     = "OFF"
}

variable "deletion_protection" {
  description = "Cognito user pool deletion protection: ACTIVE or INACTIVE. Activate for prod once stable."
  type        = string
  default     = "INACTIVE"
}

variable "secret_name_prefix" {
  description = "Environment prefix for every Secrets Manager secret name, e.g. \"PROD_\" or \"DEV_\"."
  type        = string

  validation {
    condition     = can(regex("^[A-Z][A-Z0-9]*/$", var.secret_name_prefix))
    error_message = "secret_name_prefix must be uppercase, end with a slash, and look like PROD/ or DEV/."
  }
}

variable "secret_recovery_window_in_days" {
  description = "Days Secrets Manager keeps deleted secrets recoverable. Use 0 in non-production to allow immediate recreation."
  type        = number
  default     = 7
}

variable "access_token_validity_hours" {
  description = "Access token validity in hours."
  type        = number
  default     = 1
}

variable "id_token_validity_hours" {
  description = "ID token validity in hours (Cognito max: 24)."
  type        = number
  default     = 24
}

variable "refresh_token_validity_days" {
  description = "Refresh token validity in days."
  type        = number
  default     = 30
}
