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

#Create a GCS bucket to store the remote function source code
## Use a random string for the bucket name to avoid conflicts
resource "google_storage_bucket" "function_source" {
  name                        = "gemini-multimodal-function${random_id.id.hex}"
  project                     = module.project-services.project_id
  location                    = var.multi_region
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy
  depends_on                  = [time_sleep.wait_after_apis]
}

##Upload the function source code to the bucket
resource "google_storage_bucket_object" "customer_reviews_function_source_upload" {
  name   = "function_source.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.create_function_zip.output_path
}

## Upload the zip file of the source code to GCS
resource "google_storage_bucket_object" "notebook_function_source_upload" {
  name   = "notebooks_function_source.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.create_notebook_function_zip.output_path
}

#Create a GCS bucket to the source data
## Use a random string for the bucket name to avoid conflicts
resource "google_storage_bucket" "data_source" {
  name                        = "customer_reviews-${random_id.id.hex}"
  project                     = module.project-services.project_id
  location                    = var.multi_region
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy
  depends_on                  = [time_sleep.wait_after_apis]
}
