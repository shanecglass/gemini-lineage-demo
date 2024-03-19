#Identify the default service identity for Cloud Run
resource "google_project_service_identity" "cloud_run" {
  provider = google-beta
  project  = module.project-services.project_id
  service  = "run.googleapis.com"

  depends_on = [time_sleep.wait_after_apis]
}

#Create a service account for Cloud Run authorization
resource "google_service_account" "cloud_run_invoke" {
  project      = module.project-services.project_id
  account_id   = "gemini-demo-app"
  display_name = "Cloud Run Auth Service Account"
  depends_on = [
  google_project_service_identity.cloud_run]
}

#Assign IAM permissions to the Cloud Run authorization service account
resource "google_project_iam_member" "cloud_run_invoke_roles" {
  for_each = toset([
    "roles/pubsub.publisher",        // Needs to publish Pub/Sub messages to topic
    "roles/run.invoker",             // Service account role to manage access to app
    "roles/aiplatform.user",         // Needs to predict from endpoints
    "roles/aiplatform.serviceAgent", // Service account role
    "roles/iam.serviceAccountUser",
    "roles/bigquery.admin",      // Create jobs and modify BigQuery tables
    "roles/storage.admin", // Read/write GCS files
    "roles/iam.serviceAccountTokenCreator",
    ]
  )

  project = module.project-services.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloud_run_invoke.email}"

  depends_on = [
    module.workflow_polling_4,
    google_service_account.cloud_run_invoke
  ]
}

resource "terraform_data" "bld_and_deploy" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      cd "${path.root}/src/app"
      chmod +x bld.sh
      chmod +x deploy.sh
      bash bld.sh
      bash deploy.sh
    EOT

    environment = {
      PROJECT_ID = module.project-services.project_id
      REGION     = var.region
      OUTPUT_BUCKET = google_storage_bucket.data_source.url
    }
  }
  depends_on = [google_project_iam_member.cloud_run_invoke_roles]
}
