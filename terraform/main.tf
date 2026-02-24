locals {
  project      = "jangamn-poc-4215"
  docker_image = "${var.region}-docker.pkg.dev/${local.project}/${var.service_name}/${data.archive_file.source.output_sha}"
  source_path  = "../function"
}

// Artifact Registry Repository to store cloud functions images
resource "google_artifact_registry_repository" "image_repository" {
  location      = var.region
  repository_id = var.service_name
  description   = "Docker Images for ${var.service_name}"
  format        = "DOCKER"
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

// Archive the function source code, excluding unnecessary files and directories
data "archive_file" "source" {
  type        = "zip"
  source_dir  = local.source_path
  output_path = "${local.source_path}/out/function-${var.service_name}.zip"
  excludes    = ["**/.terraform/**", "**/.git/**", "**/out/**"]
}

// Build and push the Docker image to Artifact Registry using Cloud Build
resource "terraform_data" "manual_build" {
  triggers_replace = [
    data.archive_file.source.output_sha
  ]

  provisioner "local-exec" {
    command = <<EOT
      gcloud builds submit ${local.source_path}/out/function-${var.service_name}.zip \
        --pack image=${local.docker_image},env=GOOGLE_FUNCTION_TARGET=HelloWorld
    EOT
  }
  depends_on = [google_artifact_registry_repository.image_repository]
}

// Deploy the Cloud Run Function with Datadog integration using the Terraform module
module "my-cloud-run-app" {
  source  = "DataDog/cloud-run-datadog/google"
  version = "~> 1.0"

  project  = "jangamn-poc-4215"
  name     = "dd-go-func-poc"
  location = "europe-west1"

  datadog_api_key = data.google_secret_manager_secret_version.dd_api_key_version.secret_data
  datadog_service = "dd-go-func-poc"
  datadog_env     = "development"
  datadog_site    = "datadoghq.eu"
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
      { name = "DD_SOURCE", value = "go" },
      { name = "DD_ENV", value = "development" },
    ]
  }

  datadog_enable_logging = true

  deletion_protection = false
  build_config = {
    function_target          = "HelloWorld"
    image_uri                = local.docker_image
    base_image               = "europe-west1/serverless-runtimes/google-22/runtimes/go125"
    enable_automatic_updates = true
  }
  template = {
    containers = [
      {
        name           = "main"
        image          = local.docker_image
        base_image_uri = "europe-west1/serverless-runtimes/google-22/runtimes/go125"
        resources = {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
        ports = {
          container_port = 8080
        }
        env = [
          { name = "DD_TRACE_ENABLED", value = "true" },
          { name = "DD_LOGS_INJECTION", value = "true" },
          { name = "DD_ENV", value = "development" },
          { name = "DD_SERVICE", value = "dd-go-func-poc" },
          { name = "DD_VERSION", value = "1.0.0" },
          { name = "DD_SOURCE", value = "go" },
        ]
      },
    ]
  }
  depends_on = [
    terraform_data.manual_build
  ]
}