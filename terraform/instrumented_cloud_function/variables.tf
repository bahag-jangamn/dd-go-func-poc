
variable "name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "service_account" {
  type = string
}

variable "source_path" {
  type = string
}

variable "runtime" {
  type = string
}

variable "cpu" {
  type    = string
  default = "0.09"
}

variable "memory" {
  type = string
}

variable "entry_point" {
  type = string
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "secret_variables" {
  type    = list(string)
  default = []
}

variable "timeout_seconds" {
  type    = number
  default = 300
}

variable "event_trigger_config" {
  type = object({
    trigger_region = string
    event_type     = string
    retry_policy = object({
      max_attempts = number
    })
    topic_id              = string
    service_account_email = optional(string)
    event_filters_config = optional(object({
      attribute = string
      value     = string
    }))
  })
  default = null
}

variable "max_instances" {
  type     = number
  default  = null
  nullable = true
}

variable "datadog_api_key" {
  type      = string
  sensitive = true
}

variable "datadog_environment" {
  type    = string
  default = "development"
}

variable "datadog_site" {
  type    = string
  default = "datadoghq.eu"
}

variable "datadog_source" {
  type    = string
  default = "go"
}

variable "function_runtime_image" {
  type    = string
  default = "europe-west1/serverless-runtimes/google-22/runtimes/go125"
}

variable "datadog_version" {
  type    = string
  default = "1.0.0"
}