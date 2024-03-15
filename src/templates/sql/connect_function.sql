## TODO: Update with correct values
CREATE OR REPLACE FUNCTION `${project_id}.${dataset_id}`.gemini_analysis(review_id STRING) RETURNS STRING
REMOTE WITH CONNECTION `${project_id}.${region}.${connection_id}`
OPTIONS (
      endpoint = '${function_url}',
      max_batching_rows=1)
