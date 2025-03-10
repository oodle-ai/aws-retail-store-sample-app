variable "environment_name" {
  type    = string
  default = "retail-store-ecs"
}

variable "container_image_overrides" {
  type        = any
  default     = {}
  description = "Container image override object"
}

variable "oodle_api_key" {
  type = string
}

variable "oodle_endpoint" {
  type = string
}

variable "oodle_instance" {
  type = string
}
