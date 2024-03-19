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


# Create the notebook files to be uploaded
# resource "local_file" "notebook" {
#   filename = "${path.module}/src/templates/notebook_function/notebooks/gaacsa_walkthrough.ipynb"
#   content = templatefile("${path.module}/src/templates/gaacsa_walkthrough.ipynb", {
#     PROJECT_ID         = format("\\%s${module.project-services.project_id}\\%s", "\"", "\""),
#     DATASET_ID         = format("\\%s${google_bigquery_dataset.infra_dataset.dataset_id}\\%s", "\"", "\""),
#     LINEAGE_DATASET_ID = format("\\%s${google_bigquery_dataset.lineage_dataset.dataset_id}\\%s", "\"", "\""),
#     }
#   )
# }

resource "local_file" "notebook" {
  filename = "${path.module}/src/templates/notebook_function/notebooks/gaacsa_walkthrough.ipynb"
  content = templatefile("${path.module}/src/templates/gaacsa_walkthrough.ipynb", {
    PROJECT_ID         = module.project-services.project_id,
    DATASET_ID         = google_bigquery_dataset.infra_dataset.dataset_id,
    LINEAGE_DATASET_ID = google_bigquery_dataset.lineage_dataset.dataset_id,
    }
  )
}

# Upload the Cloud Function source code to a GCS bucket
## Define/create zip file for the Cloud Function source. This includes notebooks that will be uploaded.
data "archive_file" "create_notebook_function_zip" {
  type        = "zip"
  output_path = "${path.module}/tmp/notebooks_function_source.zip"
  source_dir  = "${path.module}/src/templates/notebook_function/"

  depends_on = [local_file.notebook]
}

locals {
  dataform_region = (var.region == null ? var.region : var.region)
}

# Setup Dataform repositories to host notebooks
## Create the Dataform repos
resource "google_dataform_repository" "notebook_repo" {
  provider     = google-beta
  project      = module.project-services.project_id
  region       = local.dataform_region
  name         = "gaacsa_walkthrough"
  display_name = "Walkthrough guide for Gemini as a Customer Service Agent demo"
  labels = {
    "gemini-multimodal-demo" = true
    "single-file-asset-type" = "notebook"
  }
  depends_on = [time_sleep.wait_after_apis]
}

## Grant Cloud Function service account access to write to the repo
resource "google_dataform_repository_iam_member" "function_manage_repo" {
  provider   = google-beta
  project    = module.project-services.project_id
  region     = local.dataform_region
  role       = "roles/dataform.admin"
  member     = "serviceAccount:${google_service_account.cloud_function_manage_sa.email}"
  repository = google_dataform_repository.notebook_repo.name
  depends_on = [time_sleep.wait_after_apis, google_project_iam_member.workflow_service_account_roles, google_dataform_repository.notebook_repo]
}

## Grant Cloud Workflows service account access to write to the repo
resource "google_dataform_repository_iam_member" "workflow_manage_repo" {
  provider   = google-beta
  project    = module.project-services.project_id
  region     = local.dataform_region
  role       = "roles/dataform.admin"
  member     = "serviceAccount:${google_service_account.workflow_service_account.email}"
  repository = google_dataform_repository.notebook_repo.name

  depends_on = [google_dataform_repository_iam_member.function_manage_repo, google_dataform_repository.notebook_repo]
}
