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

variable "client_secret_secret_name" {
  description = "Name of the Secrets Manager secret that will hold the app Cognito configuration."
  type        = string
  default     = null
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
