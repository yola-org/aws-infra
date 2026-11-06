variable "bucket_name" {
  description = "Name of the single assets bucket (contains static/, listings/ and users/ prefixes)."
  type        = string
}

variable "cors_allowed_origins" {
  description = "Origins allowed to make cross-origin requests against the bucket."
  type        = list(string)
  default = [
    "https://vestioclothing.com",
    "https://www.vestioclothing.com",
    "http://localhost:3000",
  ]
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent object versions expire."
  type        = number
  default     = 90
}

variable "create_folder_placeholders" {
  description = "Create zero-byte placeholder objects so static/, listings/ and users/ show up as folders in the S3 console."
  type        = bool
  default     = true
}

variable "folder_prefixes" {
  description = "Prefixes to create as placeholder folders."
  type        = list(string)
  default     = ["static/", "listings/", "users/"]
}
