variable "name" {
  description = "Name of the SQS queue (the DLQ gets \"-dlq\" appended)."
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout of the queue. Must be >= the Lambda timeout."
  type        = number
  default     = 180
}

variable "message_retention_seconds" {
  description = "How long messages are retained in the queue."
  type        = number
  default     = 345600 # 4 days
}

variable "dlq_message_retention_seconds" {
  description = "How long messages are retained in the DLQ."
  type        = number
  default     = 1209600 # 14 days
}

variable "dlq_max_receive_count" {
  description = "Number of receive attempts before a message is moved to the DLQ."
  type        = number
  default     = 4
}
