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


# Set up the Workflow
## Create the Workflows service account to manage permissions
resource "google_service_account" "workflow_service_account" {
  project      = module.project-services.project_id
  account_id   = "cloud-workflow-sa-${random_id.id.hex}"
  display_name = "Service Account for Cloud Workflows"
  depends_on   = [time_sleep.wait_after_apis]
}

locals {
  workflow_roles = [
    "roles/workflows.admin",
    "roles/run.invoker",
    "roles/cloudfunctions.invoker",
    "roles/iam.serviceAccountTokenCreator",
    "roles/storage.objectAdmin",
    "roles/bigquery.connectionAdmin",
    "roles/bigquery.jobUser",
    "roles/bigquery.dataEditor",
    "roles/iam.serviceAccountUser"
  ]
}

## Grant the Workflow service account access needed to execute its tasks
resource "google_project_iam_member" "workflow_service_account_roles" {
  count      = length(local.workflow_roles)
  project    = module.project-services.project_id
  role       = local.workflow_roles[count.index]
  member     = "serviceAccount:${google_service_account.workflow_service_account.email}"
  depends_on = [google_project_iam_member.function_manage_roles]
}

## Create the workflow
resource "google_workflows_workflow" "workflow" {
  name            = "setup-workflow"
  project         = module.project-services.project_id
  region          = var.region
  description     = "Runs post Terraform setup steps for Solution in Console"
  service_account = google_service_account.workflow_service_account.id

  source_contents = templatefile("${path.module}/src/templates/workflow.tftpl", {
    raw_bucket         = google_storage_bucket.data_source.name
    dataset_id         = google_bigquery_dataset.infra_dataset.dataset_id
    lineage_dataset_id = google_bigquery_dataset.lineage_dataset.dataset_id,
    function_url       = google_cloudfunctions2_function.notebook_deploy_function.url
    function_name      = google_cloudfunctions2_function.notebook_deploy_function.name
  })

  depends_on = [
    random_id.id,
    google_project_iam_member.workflow_service_account_roles,
    google_bigquery_table.tbl_raw_reviews,
    google_bigquery_table.tbl_review_images,
    google_bigquery_routine.sp_remote_function_create,
    google_bigquery_connection.gcs_connection,
    google_bigquery_routine.sp_reviews_joins_create,
    google_bigquery_routine.sp_translate_create,
    google_bigquery_routine.sp_vision_ai_create,
    google_bigquery_routine.sp_nlp_create,
    google_bigquery_routine.sp_bigqueryml_generate_create,
    time_sleep.wait_after_function,
    google_storage_bucket.data_source,
    module.pubsub,

  ]
}

module "workflow_polling_1" {
  source = "./workflow_polling"

  workflow_id          = google_workflows_workflow.workflow.id
  input_workflow_state = null

  depends_on = [
    google_workflows_workflow.workflow,
  ]
}

module "workflow_polling_2" {
  source      = "./workflow_polling"
  workflow_id = google_workflows_workflow.workflow.id

  input_workflow_state = module.workflow_polling_1.workflow_state

  depends_on = [
    module.workflow_polling_1
  ]
}

module "workflow_polling_3" {
  source      = "./workflow_polling"
  workflow_id = google_workflows_workflow.workflow.id

  input_workflow_state = module.workflow_polling_2.workflow_state

  depends_on = [
    module.workflow_polling_2
  ]
}

module "workflow_polling_4" {
  source      = "./workflow_polling"
  workflow_id = google_workflows_workflow.workflow.id

  input_workflow_state = module.workflow_polling_3.workflow_state

  depends_on = [
    module.workflow_polling_3
  ]
}
