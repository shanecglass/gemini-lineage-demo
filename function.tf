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

# Upload the Cloud Function source code to a GCS bucket
## Define/create zip file for the Cloud Function source. This includes notebooks that will be uploaded
data "archive_file" "create_function_zip" {
  type        = "zip"
  output_path = "${path.module}/tmp/function_source.zip"
  source_dir  = "${path.module}/src/templates/function/"

  depends_on = [time_sleep.wait_after_apis]
}

resource "google_service_account" "cloud_function_manage_sa" {
  project      = module.project-services.project_id
  account_id   = "gemini-function-invoke-demo"
  display_name = "Cloud Functions Service Account"

  depends_on = [time_sleep.wait_after_apis]
}

resource "google_project_iam_member" "function_manage_roles" {
  for_each = toset([
    "roles/bigquery.admin",       // Create jobs and modify BigQuery tables
    "roles/cloudfunctions.admin", // Service account role to manage access to the remote function
    "roles/iam.serviceAccountUser",
    "roles/run.invoker",         // Invoke Cloud Run to execute the function
    "roles/storage.objectAdmin", // Read/write GCS files
    "roles/dataform.admin",      // Edit access code resources
    "roles/iam.serviceAccountTokenCreator",
    ]
  )
  project = module.project-services.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloud_function_manage_sa.email}"

  depends_on = [google_project_iam_member.vertex_connection_manage_roles]
}

resource "google_cloudfunctions2_function" "gaacsa" {
  name        = "analyze-reviews"
  location    = "us-central1"
  description = "Gemini as a Customer Service Agent to resolve product issues based on reviews"

  build_config {
    runtime     = "python311"
    entry_point = "run_it" # Set the entry point

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.gaacsa_function_source_upload.name
      }
    }
  }

  service_config {
    max_instance_count = 10
    #This value can be set to a non-zero integer to improve response time
    min_instance_count               = 0
    available_memory                 = "2Gi"
    timeout_seconds                  = 600
    max_instance_request_concurrency = 1
    available_cpu                    = "4"
    ingress_settings                 = "ALLOW_ALL"
    all_traffic_on_latest_revision   = true
    service_account_email            = google_service_account.cloud_function_manage_sa.email
    environment_variables = {
      "PROJECT_ID" : "${module.project-services.project_id}",
      "REGION" : "${var.region}"
      "OUTPUT_BUCKET" : "${google_storage_bucket.data_source}"
    }
  }

  depends_on = [google_project_iam_member.function_manage_roles]

}


# Create and deploy a Cloud Function to deploy notebooks
## Create the Cloud Function
resource "google_cloudfunctions2_function" "notebook_deploy_function" {
  name        = "deploy-notebooks"
  project     = module.project-services.project_id
  location    = var.region
  description = "A Cloud Function that deploys sample notebooks."
  build_config {
    runtime     = "python311"
    entry_point = "run_it"

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.notebook_function_source_upload.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    # min_instance_count can be set to 1 to improve performance and responsiveness
    min_instance_count               = 0
    available_memory                 = "512Mi"
    timeout_seconds                  = 300
    max_instance_request_concurrency = 1
    available_cpu                    = "2"
    ingress_settings                 = "ALLOW_ALL"
    all_traffic_on_latest_revision   = true
    service_account_email            = google_service_account.cloud_function_manage_sa.email
    environment_variables = {
      "PROJECT_ID" : module.project-services.project_id,
      "REGION" : local.dataform_region
    }
  }

  depends_on = [
    time_sleep.wait_after_apis,
    google_project_iam_member.function_manage_roles,
    google_dataform_repository.notebook_repo,
    google_dataform_repository_iam_member.workflow_manage_repo,
    google_dataform_repository_iam_member.function_manage_repo
  ]
}

## Wait for Function deployment to complete
resource "time_sleep" "wait_after_function" {
  create_duration = "5s"
  depends_on      = [google_cloudfunctions2_function.notebook_deploy_function, google_cloudfunctions2_function.gaacsa]
}
