/*
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module "project-services" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  version                     = "14.4"
  disable_services_on_destroy = false

  project_id  = var.project_id
  enable_apis = var.enable_apis

  activate_apis = [
    "aiplatform.googleapis.com",
    "bigquery.googleapis.com",
    "bigqueryconnection.googleapis.com",
    "bigquerystorage.googleapis.com",
    "cloudapis.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "compute.googleapis.com",
    "config.googleapis.com",
    "dataflow.googleapis.com",
    "dataform.googleapis.com",
    "dataplex.googleapis.com",
    "language.googleapis.com",
    "logging.googleapis.com",
    "notebooks.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "storage-api.googleapis.com",
    "translate.googleapis.com",
    "vision.googleapis.com",
    "workflows.googleapis.com",
  ]

  activate_api_identities = [
    {
      api = "workflows.googleapis.com"
      roles = [
        "roles/workflows.viewer"
      ]
      api = "cloudfunctions.googleapis.com"
      roles = [
        "roles/cloudfunctions.invoker"
      ]
      api = "run.googleapis.com"
      roles = [
        "roles/run.invoker"
      ]
      api = "pubsub.googleapis.com"
      roles = [
        "roles/pubsub.publisher"
      ]
    }
  ]
}

#Pause after API activation
resource "time_sleep" "wait_after_apis" {
  depends_on      = [module.project-services]
  create_duration = "60s"
}

resource "random_id" "id" {
  byte_length = 4
  depends_on  = [time_sleep.wait_after_apis]
}

data "google_client_config" "current" {
}

data "http" "cloud_run_uri" {
  url    = "https://run.googleapis.com/v2/projects/${module.project-services.project_id}/locations/${var.region}/services/gemini-multimodal-demo"
  method = "GET"
  request_headers = {
    Accept = "application/json"
  Authorization = "Bearer ${data.google_client_config.current.access_token}" }
  depends_on = [terraform_data.bld_and_deploy]
}

## Parse out the workflow execution state from the API call response
locals {
  response_body = jsondecode(data.http.cloud_run_uri.response_body)
  run_uri       = local.response_body.uri
  depends_on    = [data.http.cloud_run_uri]
}

