locals {
  project     = "jangamn-poc-4215"
  source_path = "../function"
}

// Retrieve Datadog API key from Secret Manager
data "google_secret_manager_secret" "dd_api_key" {
  secret_id = "datadog-api-key"
}

// Retrieve the latest version of the Datadog API key secret
data "google_secret_manager_secret_version" "dd_api_key_version" {
  secret  = data.google_secret_manager_secret.dd_api_key.id
  version = "1"
}

module "dd-poc-service" {
  source                = "./instrumented_cloud_function"
  project_id            = local.project
  region                = var.region
  name                  = "dd-go-func-poc"
  service_account       = var.service_account
  environment_variables = var.environment_variables
  secret_variables      = var.secret_variables
  datadog_api_key       = data.google_secret_manager_secret_version.dd_api_key_version.secret_data
  entry_point           = "HelloWorld"
  memory                = "512Mi"
  cpu                   = "1"
  runtime               = "europe-west1/serverless-runtimes/google-22/runtimes/go125"
  source_path           = local.source_path
  event_trigger_config = var.event_trigger_config
}

// Deploy the Cloud Run Function with Datadog integration using the Terraform module
# module "my-cloud-run-app" {
#   source  = "DataDog/cloud-run-datadog/google"
#   version = "~> 1.0"
#
#   project  = "jangamn-poc-4215"
#   name     = "dd-go-func-poc"
#   location = "europe-west1"
#
#   datadog_api_key = data.google_secret_manager_secret_version.dd_api_key_version.secret_data
#   datadog_service = "dd-go-func-poc"
#   datadog_env     = "development"
#   datadog_site    = "datadoghq.eu"
#   datadog_sidecar = {
#     env = [
#       {
#         name  = "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT"
#         value = "localhost:4318"
#       },
#       {
#         name  = "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_GRPC_ENDPOINT"
#         value = "localhost:4317"
#       },
#       { name = "DD_SOURCE", value = "go" },
#       { name = "DD_ENV", value = "development" },
#     ]
#   }
#
#   datadog_enable_logging = true
#
#   deletion_protection = false
#   build_config = {
#     function_target          = "HelloWorld"
#     image_uri                = local.docker_image
#     base_image               = "europe-west1/serverless-runtimes/google-22/runtimes/go125"
#     enable_automatic_updates = true
#   }
#   ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
#   template = {
#     service_account = var.service_account
#     timeout         = "300s"
#     containers = [
#       {
#         name           = "main"
#         image          = local.docker_image
#         base_image_uri = "europe-west1/serverless-runtimes/google-22/runtimes/go125"
#         resources = {
#           limits = {
#             cpu    = "1"
#             memory = "512Mi"
#           }
#         }
#         ports = {
#           container_port = 8080
#         }
#         env = concat(
#           [
#             for k, v in var.environment_variables : {
#               name  = k
#               value = v
#             }
#           ],
#           [
#             for secret_name in var.secret_variables : {
#               name = secret_name
#               value_source = {
#                 secret_key_ref = {
#                   secret  = secret_name
#                   version = "latest"
#                 }
#               }
#             }
#           ]
#         )
#       },
#     ],
#     scaling = {
#       max_instance_count = 1
#     }
#   }
#   depends_on = [
#     terraform_data.manual_build
#   ]
# }
#
# resource "google_eventarc_trigger" "event_trigger" {
#   count    = var.event_trigger_config == null ? 0 : 1
#   name     = var.service_name
#   location = var.event_trigger_config["trigger_region"]
#
#   dynamic "matching_criteria" {
#     for_each = var.event_trigger_config.event_filters_config == null ? [] : [1]
#     content {
#       attribute = var.event_trigger_config.event_filters_config.attribute
#       value     = var.event_trigger_config.event_filters_config.value
#     }
#   }
#
#   retry_policy {
#     max_attempts = 1
#   }
#
#   destination {
#     cloud_run_service {
#       service = var.service_name
#       region  = var.region
#     }
#   }
#
#   transport {
#     pubsub {
#       topic = var.event_trigger_config["topic_id"]
#     }
#   }
#
#   service_account = var.event_trigger_config.service_account_email
# }