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

/*
 * Create Pub/Sub topics to capture both prompts and responses
 * This module also creates the subscription that writes the raw prompts/response data to the appropriate BigQuery table
*/

#Create a service account for Cloud Run authorization

resource "google_pubsub_topic" "topics" {
  for_each   = toset(var.resource_purpose)
  name      = "gemini-multimodal-demo${each.key}"

  labels = var.labels

  message_retention_duration = "86600s"
}

resource "google_pubsub_subscription" "subs" {
  provider = google
  for_each   = toset(var.resource_purpose)
  topic     = google_pubsub_topic.topics[each.key].name
  name      = "write-to-bq-${each.key}"


  bigquery_config {
    table = "${module.project-services.project_id}.${google_bigquery_dataset.lineage_dataset.dataset_id}.${each.key}"
    use_table_schema = true
  }
}

resource "google_project_service_identity" "pubsub_sa" {
  provider = google-beta

  project = module.project-services.project_id
  service = "pubsub.googleapis.com"
}

resource "google_project_iam_member" "pubsub_sa_auth" {
  project = module.project-services.project_id
  for_each = toset([
    "roles/bigquery.metadataViewer",
    "roles/bigquery.dataEditor",
  ])
  role    = each.key
  member = "serviceAccount:${google_project_service_identity.pubsub_sa.email}"
}

