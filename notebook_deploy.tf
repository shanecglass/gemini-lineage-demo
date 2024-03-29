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

locals {
  notebook_names = [
    for s in fileset("${path.module}/src/templates/notebooks/", "*.ipynb") : trimsuffix(s, ".ipynb")
  ]
}

resource "local_file" "notebook" {
  count    = length(local.notebook_names)
  filename = "${path.module}/src/templates/notebook_function/notebooks/${local.notebook_names[count.index]}.ipynb"
  content = templatefile("${path.module}/src/templates/notebooks/${local.notebook_names[count.index]}.ipynb", {
    PROJECT_ID           = module.project-services.project_id,
    INFRA_DATASET_ID     = google_bigquery_dataset.infra_dataset.dataset_id,
    MARKETING_DATASET_ID = google_bigquery_dataset.marketing_dataset.dataset_id,
    LINEAGE_DATASET_ID   = google_bigquery_dataset.lineage_dataset.dataset_id,
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
  count        = length(local.notebook_names)
  provider     = google-beta
  project      = module.project-services.project_id
  region       = local.dataform_region
  name         = local.notebook_names[count.index]
  display_name = replace(local.notebook_names[count.index], "_", " ")
  labels = {
    "gemini-multimodal-demo" = true
    "single-file-asset-type" = "notebook"
  }
  depends_on = [time_sleep.wait_after_apis]
}
# Manage Cloud Function permissions and access
## Create a service account to manage the function
resource "google_service_account" "notebook_cloud_function_manage_sa" {
  project                      = module.project-services.project_id
  account_id                   = "notebook-deployment"
  display_name                 = "Cloud Functions Service Account"
  description                  = "Service account used to manage Cloud Function"
  create_ignore_already_exists = var.create_ignore_service_accounts

  depends_on = [
    time_sleep.wait_after_apis,
  ]
}

## Define the IAM roles that are granted to the Cloud Function service account
locals {
  cloud_function_roles = [
    "roles/cloudfunctions.admin", // Service account role to manage access to the remote function
    "roles/dataform.admin",       // Edit access code resources
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator",
    "roles/run.invoker",         // Service account role to invoke the remote function
    "roles/storage.objectViewer" // Read GCS files
  ]
}

## Assign required permissions to the function service account
resource "google_project_iam_member" "notebook_function_manage_roles" {
  project = module.project-services.project_id
  count   = length(local.cloud_function_roles)
  role    = local.cloud_function_roles[count.index]
  member  = "serviceAccount:${google_service_account.notebook_cloud_function_manage_sa.email}"

  depends_on = [google_service_account.notebook_cloud_function_manage_sa]
}

## Grant the Cloud Workflows service account access to act as the Cloud Function service account
resource "google_service_account_iam_member" "workflow_auth_function" {
  service_account_id = google_service_account.notebook_cloud_function_manage_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.workflow_service_account.email}"

  depends_on = [
    google_service_account.workflow_service_account,
    google_project_iam_member.notebook_function_manage_roles
  ]
}

## Grant Cloud Function service account access to write to the repo
resource "google_dataform_repository_iam_member" "function_manage_repo" {
  provider   = google-beta
  project    = module.project-services.project_id
  region     = local.dataform_region
  role       = "roles/dataform.admin"
  member     = "serviceAccount:${google_service_account.notebook_cloud_function_manage_sa.email}"
  count      = length(local.notebook_names)
  repository = local.notebook_names[count.index]

  depends_on = [time_sleep.wait_after_apis, google_service_account_iam_member.workflow_auth_function, google_dataform_repository.notebook_repo]
}

## Grant Cloud Workflows service account access to write to the repo
resource "google_dataform_repository_iam_member" "workflow_manage_repo" {
  provider   = google-beta
  project    = module.project-services.project_id
  region     = local.dataform_region
  role       = "roles/dataform.admin"
  member     = "serviceAccount:${google_service_account.workflow_service_account.email}"
  count      = length(local.notebook_names)
  repository = local.notebook_names[count.index]


  depends_on = [
    google_project_iam_member.workflow_service_account_roles,
    google_service_account_iam_member.workflow_auth_function,
    google_dataform_repository_iam_member.function_manage_repo,
    google_dataform_repository.notebook_repo
  ]
}
