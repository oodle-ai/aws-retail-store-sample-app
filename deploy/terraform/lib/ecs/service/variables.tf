variable "environment_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "cluster_arn" {
  description = "ECS cluster ARN"
  type        = string
}

variable "tags" {
  description = "List of tags to be associated with resources."
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs."
  type        = list(string)
}

variable "container_image" {
  description = "Container image for the service"
}

variable "environment_variables" {
  description = "Map of environment variables for the ECS task"
  default     = {}
}

variable "secrets" {
  description = "Map of secrets for the ECS task"
  default     = {}
}

variable "additional_task_role_iam_policy_arns" {
  description = "Additional IAM policy ARNs to be added to the task role"
  default     = []
}

variable "additional_task_execution_role_iam_policy_arns" {
  description = "Additional IAM policy ARNs to be added to the task execution role"
  default     = []
}

variable "healthcheck_path" {
  description = "HTTP path used to health check the service"
  default     = "/health"
}

variable "cloudwatch_logs_group_id" {
  description = "CloudWatch logs group ID"
}

variable "alb_target_group_arn" {
  description = "ARN of the ALB target group the ECS service should register tasks to"
  default     = ""
}

variable "datadog_api_key" {
  description = "Datadog API key for container monitoring"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (e.g., 'datadoghq.com', 'datadoghq.eu')"
  type        = string
  default     = "us5.datadoghq.com"
}

variable "oodle_site" {
  description = "Oodle site"
  type        = string
}

variable "oodle_log_collector_host" {
  description = "Oodle log collector host"
  type        = string
}

variable "oodle_instance" {
  description = "Oodle instance"
  type        = string
}

variable "oodle_api_key" {
  description = "Oodle API key for container monitoring"
  type        = string
  sensitive   = true
}

variable "route53_zone_id" {
  description = "The ID of the Route53 hosted zone where DNS records will be created"
  type        = string
}

variable "fluent_bit_config_bucket_name" {
  description = "Name of the S3 bucket for fluent-bit configurations"
  type        = string
  default     = "oodle-fluent-bit-configs"
}
