
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