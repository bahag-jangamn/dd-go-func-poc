
variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
  default     = "jangamn-poc-4215"
}

variable "region" {
  description = "The region in which to provision resources."
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "The zone in which to provision resources."
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "The name of the service to be used as a prefix for the state file in the GCS backend."
  type        = string
  default     = "dd-go-func-poc"
}

variable "datadog_version" {
  description = "The version of the Datadog provider to use"
  type        = string
  default     = "3.0.0"
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
  default = {
    trigger_region        = "europe-west1"
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    retry_policy          = { max_attempts = 1 }
    topic_id              = "projects/jangamn-poc-4215/topics/dd-poc-topic"
    service_account_email = "dd-poc-sa@jangamn-poc-4215.iam.gserviceaccount.com"
    event_filters_config = {
      attribute = "type"
      value     = "google.cloud.pubsub.topic.v1.messagePublished"
    }
  }
}

variable "service_account" {
  type    = string
  default = "dd-poc-sa@jangamn-poc-4215.iam.gserviceaccount.com"
}

variable "environment_variables" {
  type = map(string)
  default = {
    DD_TRACE_ENABLED  = "true"
    DD_LOGS_INJECTION = "true"
    DD_ENV            = "development"
    DD_SERVICE        = "dd-go-func-poc"
    DD_VERSION        = "1.0.0"
    DD_SOURCE         = "go"
  }
}

variable "secret_variables" {
  type    = list(string)
  default = []
}