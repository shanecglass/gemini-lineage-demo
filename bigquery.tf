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

#Create resource connection for GCS
resource "google_bigquery_connection" "gcs_connection" {
  project       = module.project-services.project_id
  connection_id = "gcs_connection"
  location      = var.multi_region
  friendly_name = "GCS connection"
  description   = "Connecting to GCS resources"
  cloud_resource {}
  depends_on = [time_sleep.wait_after_apis]
}

resource "google_project_iam_member" "gcs_connection_iam_object_viewer" {
  project = module.project-services.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_bigquery_connection.gcs_connection.cloud_resource[0].service_account_id}"

  depends_on = [google_storage_bucket.data_source, google_bigquery_connection.gcs_connection]
}

#Create destination dataset for data tables
resource "google_bigquery_dataset" "infra_dataset" {
  project    = module.project-services.project_id
  dataset_id = var.bq_dataset
  location   = var.multi_region
  depends_on = [time_sleep.wait_after_apis]
}

## Create a Biglake table for users
resource "google_bigquery_table" "tbl_users" {
  dataset_id          = google_bigquery_dataset.infra_dataset.dataset_id
  table_id            = "users"
  project             = module.project-services.project_id
  deletion_protection = var.deletion_protection

  schema = file("${path.module}/src/schema/cymbal_sports_users.json")

  external_data_configuration {
    autodetect    = true
    connection_id = google_bigquery_connection.gcs_connection.name
    source_format = "PARQUET"
    source_uris   = ["gs://${google_storage_bucket.data_source.name}/cymbal-sports/bq-data/cymbal_sports_users.parquet"]
  }

  labels     = var.labels
  depends_on = [google_project_iam_member.gcs_connection_iam_object_viewer]
}

resource "google_bigquery_table" "tbl_order_items" {
  dataset_id          = google_bigquery_dataset.infra_dataset.dataset_id
  table_id            = "order_items"
  project             = module.project-services.project_id
  deletion_protection = var.deletion_protection

  schema = file("${path.module}/src/schema/order_items.json")

  external_data_configuration {
    autodetect    = true
    connection_id = google_bigquery_connection.gcs_connection.name
    source_format = "PARQUET"
    source_uris   = ["gs://${google_storage_bucket.data_source.name}/cymbal-sports/bq-data/order_items.parquet"]
  }

  labels     = var.labels
  depends_on = [google_project_iam_member.gcs_connection_iam_object_viewer]
}

## Create a GCS Object Table for raw reviews
resource "google_bigquery_table" "tbl_raw_reviews" {
  dataset_id          = google_bigquery_dataset.infra_dataset.dataset_id
  table_id            = "raw_reviews"
  project             = module.project-services.project_id
  deletion_protection = var.deletion_protection

  schema = file("${path.module}/src/schema/raw_reviews.json")

  external_data_configuration {
    autodetect    = true
    connection_id = google_bigquery_connection.gcs_connection.name
    source_format = "PARQUET"
    source_uris   = ["gs://${google_storage_bucket.data_source.name}/cymbal-sports/bq-data/raw_reviews.parquet"]
  }

  labels     = var.labels
  depends_on = [google_project_iam_member.gcs_connection_iam_object_viewer]

}

## Create a GCS Object Table for the product list reviews
resource "google_bigquery_table" "tbl_product_list" {
  dataset_id          = google_bigquery_dataset.infra_dataset.dataset_id
  table_id            = "products"
  project             = module.project-services.project_id
  deletion_protection = var.deletion_protection

  schema = file("${path.module}/src/schema/product_list.json")

  external_data_configuration {
    autodetect    = true
    connection_id = google_bigquery_connection.gcs_connection.name
    source_format = "PARQUET"
    source_uris   = ["gs://${google_storage_bucket.data_source.name}/cymbal-sports/bq-data/products.parquet"]
  }

  labels     = var.labels
  depends_on = [google_project_iam_member.gcs_connection_iam_object_viewer]

}

## Create a Biglake table for ISO 639 codes
resource "google_bigquery_table" "tbl_iso_639_codes" {
  dataset_id          = google_bigquery_dataset.infra_dataset.dataset_id
  table_id            = "iso_639_codes"
  project             = module.project-services.project_id
  deletion_protection = var.deletion_protection

  schema = file("${path.module}/src/schema/iso_639_codes.json")

  external_data_configuration {
    autodetect    = true
    connection_id = google_bigquery_connection.gcs_connection.name
    source_format = "PARQUET"
    source_uris   = ["gs://${google_storage_bucket.data_source.name}/cymbal-sports/bq-data/iso_639_codes.parquet"]
  }

  labels     = var.labels
  depends_on = [google_project_iam_member.gcs_connection_iam_object_viewer]
}

#Create object tables
##Create GCS object table for inventory images
resource "google_bigquery_table" "inventory_images" {
  project             = module.project-services.project_id
  dataset_id          = google_bigquery_dataset.infra_dataset.dataset_id
  table_id            = "inventory_images"
  deletion_protection = var.deletion_protection

  external_data_configuration {
    autodetect      = false
    connection_id   = google_bigquery_connection.gcs_connection.name
    source_uris     = ["${google_storage_bucket.data_source.url}/cymbal-sports/inventory_images/*.png"]
    object_metadata = "Simple"
  }

  labels     = var.labels
  depends_on = [google_project_iam_member.gcs_connection_iam_object_viewer]
}

##Create GCS object table for review images
resource "google_bigquery_table" "tbl_review_images" {
  project             = module.project-services.project_id
  dataset_id          = google_bigquery_dataset.infra_dataset.dataset_id
  table_id            = "review_images"
  deletion_protection = var.deletion_protection

  external_data_configuration {
    autodetect      = false
    connection_id   = google_bigquery_connection.gcs_connection.name
    source_uris     = ["${google_storage_bucket.data_source.url}/cymbal-sports/review_images/*.png"]
    object_metadata = "Simple"
  }

  labels     = var.labels
  depends_on = [google_project_iam_member.gcs_connection_iam_object_viewer]
}

##Create GCS object table for customer service policy
resource "google_bigquery_table" "service_policy" {
  project             = module.project-services.project_id
  dataset_id          = google_bigquery_dataset.infra_dataset.dataset_id
  table_id            = "service_policy"
  deletion_protection = var.deletion_protection

  external_data_configuration {
    autodetect      = false
    connection_id   = google_bigquery_connection.gcs_connection.name
    source_uris     = ["${google_storage_bucket.data_source.url}/cymbal-sports/service_policy/*.png"]
    object_metadata = "Simple"
  }

  labels     = var.labels
  depends_on = [google_project_iam_member.gcs_connection_iam_object_viewer]
}

#Create destination dataset for prompt and response tables
resource "google_bigquery_dataset" "lineage_dataset" {
  project    = module.project-services.project_id
  dataset_id = "${var.bq_dataset}_lineage"
  location   = var.multi_region
  depends_on = [time_sleep.wait_after_apis]
}

## Create landing table for raw prompt and response inputs
resource "google_bigquery_table" "pubsub_dest_tables" {
  for_each            = toset(var.resource_purpose)
  project             = module.project-services.project_id
  dataset_id          = google_bigquery_dataset.lineage_dataset.dataset_id
  table_id            = each.key
  deletion_protection = false

  time_partitioning {
    field = "publish_time"
    type  = "HOUR"
  }

  schema = file("${path.module}/src/schema/${each.key}.json")
}

#Create resource connection for Vertex AI
resource "google_bigquery_connection" "vertex_connection" {
  project       = module.project-services.project_id
  connection_id = "vertex_ai_connection"
  location      = var.multi_region
  friendly_name = "Vertex AI connection"
  description   = "Connecting to the Vertex AI resources"
  cloud_resource {}
  depends_on = [time_sleep.wait_after_apis, google_project_iam_member.gcs_connection_iam_object_viewer]
}

## Add IAM permissions for the
resource "google_project_iam_member" "vertex_connection_manage_roles" {
  for_each = toset([
    "roles/aiplatform.user",
    "roles/bigquery.connectionUser",
    "roles/serviceusage.serviceUsageConsumer",
    ]
  )
  project = module.project-services.project_id
  role    = each.key
  member  = "serviceAccount:${google_bigquery_connection.vertex_connection.cloud_resource[0].service_account_id}"

  depends_on = [google_project_iam_member.gcs_connection_iam_object_viewer]
}

## Create Bigquery ML Model for using text generation
resource "google_bigquery_routine" "sp_bigqueryml_generate_create" {
  project      = module.project-services.project_id
  dataset_id   = google_bigquery_dataset.infra_dataset.dataset_id
  routine_id   = "sp_generate_create"
  routine_type = "PROCEDURE"
  language     = "SQL"

  definition_body = templatefile("${path.module}/src/templates/sql/create_models/generate_text.sql", {
    project_id    = module.project-services.project_id,
    dataset_id    = google_bigquery_dataset.infra_dataset.dataset_id,
    region        = var.multi_region
    connection_id = google_bigquery_connection.vertex_connection.connection_id,
    }
  )
  depends_on = [google_project_iam_member.vertex_connection_manage_roles]
}

## Create Bigquery ML Model for using NLP
resource "google_bigquery_routine" "sp_nlp_create" {
  project      = module.project-services.project_id
  dataset_id   = google_bigquery_dataset.infra_dataset.dataset_id
  routine_id   = "sp_nlp_create"
  routine_type = "PROCEDURE"
  language     = "SQL"

  definition_body = templatefile("${path.module}/src/templates/sql/create_models/nlp.sql", {
    project_id    = module.project-services.project_id,
    dataset_id    = google_bigquery_dataset.infra_dataset.dataset_id,
    region        = var.multi_region
    connection_id = google_bigquery_connection.vertex_connection.connection_id,
    }
  )
  depends_on = [google_project_iam_member.vertex_connection_manage_roles]
}

## Create Bigquery ML Model for using Vision AI
resource "google_bigquery_routine" "sp_vision_ai_create" {
  project      = module.project-services.project_id
  dataset_id   = google_bigquery_dataset.infra_dataset.dataset_id
  routine_id   = "sp_vision_ai_create"
  routine_type = "PROCEDURE"
  language     = "SQL"

  definition_body = templatefile("${path.module}/src/templates/sql/create_models/vision_ai.sql", {
    project_id    = module.project-services.project_id,
    dataset_id    = google_bigquery_dataset.infra_dataset.dataset_id,
    region        = var.multi_region
    connection_id = google_bigquery_connection.vertex_connection.connection_id,
    }
  )
  depends_on = [google_project_iam_member.vertex_connection_manage_roles]
}

## Create Bigquery ML Model for using Translate
resource "google_bigquery_routine" "sp_translate_create" {
  project      = module.project-services.project_id
  dataset_id   = google_bigquery_dataset.infra_dataset.dataset_id
  routine_id   = "sp_translate_create"
  routine_type = "PROCEDURE"
  language     = "SQL"

  definition_body = templatefile("${path.module}/src/templates/sql/create_models/translate.sql", {
    project_id    = module.project-services.project_id,
    dataset_id    = google_bigquery_dataset.infra_dataset.dataset_id,
    region        = var.multi_region
    connection_id = google_bigquery_connection.vertex_connection.connection_id,
    }
  )
  depends_on = [google_project_iam_member.vertex_connection_manage_roles]
}

## Create the raw_reviews_joined table stored procedure
resource "google_bigquery_routine" "sp_raw_reviews_joined_create" {
  project      = module.project-services.project_id
  dataset_id   = google_bigquery_dataset.infra_dataset.dataset_id
  routine_id   = "sp_raw_reviews_joined_create"
  routine_type = "PROCEDURE"
  language     = "SQL"

  definition_body = templatefile("${path.module}/src/templates/sql/join_with_review_images.sql", {
    project_id        = module.project-services.project_id,
    dataset_id        = google_bigquery_dataset.infra_dataset.dataset_id,
    raw_reviews_table = google_bigquery_table.tbl_raw_reviews.table_id,
    object_table      = google_bigquery_table.tbl_review_images.table_id,
    region            = var.multi_region
    }
  )
  depends_on = [google_project_iam_member.gcs_connection_iam_object_viewer]
}

## Create the raw_reviews_joined table stored procedure
resource "google_bigquery_routine" "sp_remote_function_create" {
  project      = module.project-services.project_id
  dataset_id   = google_bigquery_dataset.lineage_dataset.dataset_id
  routine_id   = "sp_remote_function_create"
  routine_type = "PROCEDURE"
  language     = "SQL"

  definition_body = templatefile("${path.module}/src/templates/sql/connect_function.sql", {
    project_id    = module.project-services.project_id,
    dataset_id    = google_bigquery_dataset.lineage_dataset.dataset_id,
    region        = var.multi_region,
    connection_id = google_bigquery_connection.vertex_connection.name,
    function_url  = google_cloudfunctions2_function.gaacsa.url,
    }
  )
  depends_on = [google_project_iam_member.function_manage_roles,
    google_project_iam_member.vertex_connection_manage_roles
  ]
}

## Create the stored procedure to create the cleaned prompt lineage table
resource "google_bigquery_routine" "sp_lineage_cleaning_create" {
  for_each     = toset(var.resource_purpose)
  project      = module.project-services.project_id
  dataset_id   = google_bigquery_dataset.infra_dataset.dataset_id
  routine_id   = "sp_${each.key}_cleaning_create"
  routine_type = "PROCEDURE"
  language     = "SQL"

  definition_body = templatefile("${path.module}/src/templates/sql/lineage/${each.key}_cleaning.sql", {
    project_id         = module.project-services.project_id,
    lineage_dataset_id = google_bigquery_dataset.lineage_dataset.dataset_id,
    }
  )
  depends_on = [google_bigquery_table.pubsub_dest_tables]
}

## Create the stored procedure to parse text from customer service policy
resource "google_bigquery_job" "parse_service_policy" {
  project = module.project-services.project_id
  job_id  = "parse_service_policy_${random_id.id}"

  query {
    query = templatefile("${path.module}/src/templates/sql/doc_parsing/parse_text.sql", {
      project_id = module.project-services.project_id,
      dataset_id = google_bigquery_dataset.infra_dataset.dataset_id,
    })
    create_disposition = "CREATE_IF_NEEDED"
    write_disposition  = "WRITE_TRUNCATE"
    use_legacy_sql     = false
  }
  depends_on = [google_project_iam_member.function_manage_roles,
    google_project_iam_member.vertex_connection_manage_roles,
    google_bigquery_routine.sp_vision_ai_create,
    module.workflow_polling_4
  ]
}
