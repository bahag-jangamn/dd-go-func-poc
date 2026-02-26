locals {
  docker_image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.name}/${data.archive_file.source.output_sha}"
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = var.source_path
  output_path = "${var.source_path}/out/function-${var.name}.zip"
  excludes = [
    "out",
  ]
}

resource "google_artifact_registry_repository" "image_repository" {
  location      = var.region
  repository_id = var.name
  description   = "Docker Images for ${var.name}"
  format        = "DOCKER"
}


resource "terraform_data" "manual_build" {
  triggers_replace = [
    data.archive_file.source.output_sha
  ]

  provisioner "local-exec" {
    command = <<EOT
      gcloud builds submit ${var.source_path}/out/function-${var.name}.zip \
        --pack image=${local.docker_image},env=GOOGLE_FUNCTION_TARGET=${var.entry_point}
    EOT
  }
  depends_on = [google_artifact_registry_repository.image_repository]
}

module "instrumented-cloud-function" {
  source  = "DataDog/cloud-run-datadog/google"
  version = "~> 1.0"

  project  = var.project_id
  name     = var.name
  location = var.region

  datadog_api_key = sensitive(var.datadog_api_key)
  datadog_service = var.name
  datadog_env     = var.datadog_environment
  datadog_site    = var.datadog_site
  datadog_sidecar = {
    env = [
      {
        name  = "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT"
        value = "localhost:4318"
      },
      {
        name  = "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_GRPC_ENDPOINT"
        value = "localhost:4317"
      },
      { name = "DD_SOURCE", value = var.datadog_source },
      { name = "DD_ENV", value = var.datadog_environment },
    ]
  }

  datadog_enable_logging = true

  deletion_protection = false
  build_config = {
    function_target          = var.entry_point
    image_uri                = local.docker_image
    base_image               = var.function_runtime_image
    enable_automatic_updates = true
    environment_variables    = var.environment_variables
  }
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  template = {
    containers = [
      {
        name           = "main"
        image          = local.docker_image
        base_image_uri = var.function_runtime_image
        resources = {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
        }
        ports = {
          container_port = 8080
        }
        env = concat(
          [
            for k, v in var.environment_variables : {
              name  = k
              value = v
            }
          ],
          [
            for secret_name in var.secret_variables : {
              name = secret_name
              value_source = {
                secret_key_ref = {
                  secret  = secret_name
                  version = "latest"
                }
              }
            }
          ]
        ),
        service_account = var.service_account
        timeout         = var.timeout_seconds
      },
    ],
    scaling = {
      max_instance_count = var.max_instances
    }

  }
  depends_on = [
    terraform_data.manual_build
  ]
}

resource "google_eventarc_trigger" "event_trigger" {
  count    = var.event_trigger_config == null ? 0 : 1
  name     = var.name
  location = var.event_trigger_config.trigger_region

  dynamic "matching_criteria" {
    for_each = var.event_trigger_config.event_filters_config == null ? [] : [1]
    content {
      attribute = var.event_trigger_config.event_filters_config.attribute
      value     = var.event_trigger_config.event_filters_config.value
    }
  }

  retry_policy {
    max_attempts = var.event_trigger_config.retry_policy.max_attempts
  }

  destination {
    cloud_run_service {
      service = var.name
      region  = var.region
    }
  }

  transport {
    pubsub {
      topic = var.event_trigger_config.topic_id
    }
  }

  service_account = var.event_trigger_config.service_account_email

  depends_on = [module.instrumented-cloud-function]
}