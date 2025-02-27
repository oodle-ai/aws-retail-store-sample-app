variable "environment_name" {
  type    = string
  default = "retail-store-ecs"
}

variable "container_image_overrides" {
  type        = any
  default     = {}
  description = "Container image override object"
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (e.g., 'datadoghq.com', 'datadoghq.eu')"
  type        = string
  default     = "us5.datadoghq.com"
}

variable "oodle_api_key" {
  description = "Oodle API key for container monitoring"
  type        = string
  sensitive   = true
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
