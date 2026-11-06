variable "name_prefix" {
  description = "Prefix for resource names in this module."
  type        = string
  default     = "vestio-backend"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread public subnets across (must be valid in the chosen region)."
  type        = list(string)
  default     = ["ca-central-1a", "ca-central-1b"]
}

variable "instance_type" {
  description = "EC2 instance type for app instances."
  type        = string
  default     = "t3.small"
}

variable "desired_capacity" {
  description = "Desired ASG size."
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum ASG size."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum ASG size."
  type        = number
  default     = 4
}

variable "app_port" {
  description = "Port the Spring Boot app listens on inside the container."
  type        = number
  default     = 8080
}

variable "host_port" {
  description = "Host port to publish the container on (ALB targets this port)."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "ALB health check path. vestio-backend has no actuator yet; '/' is used by default."
  type        = string
  default     = "/"
}

variable "health_check_matcher" {
  description = "HTTP codes considered healthy. Widen to include 401/403 if Spring Security rejects unauthenticated probes."
  type        = string
  default     = "200-399"
}

variable "cpu_target_tracking" {
  description = "Target CPU utilization (%%) for ASG target tracking scaling."
  type        = number
  default     = 60
}

variable "acm_certificate_arn" {
  description = "ARN of an ACM certificate for the HTTPS (443) listener. Empty = HTTP only."
  type        = string
  default     = ""
}

variable "environment_variables" {
  description = "Non-secret environment variables for the app container."
  type        = map(string)
  default     = { AWS_REGION = "ca-central-1" }
}

variable "environment_variables_sensitive" {
  description = "Sensitive environment variables merged into the container. Never commit real values."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "ecr_repository_url" {
  description = "Full URL of the ECR repository to pull the app image from."
  type        = string
}

variable "image_tag" {
  description = "Tag of the app image to run on instances."
  type        = string
  default     = "latest"
}

variable "service_role_name" {
  description = "Name of the IAM instance profile to attach (created by the environment's service_role module)."
  type        = string
}
