variable "repositories" {
  description = "ECR repository names to create."
  type        = list(string)
}

variable "image_retention_count" {
  description = "Number of tagged images to keep per repository (older ones are expired)."
  type        = number
  default     = 20
}
