  -- CREATE OR REPLACE TABLE `${project_id}.${dataset_id}.llm_customer_service_policy_parsed`
  -- AS
with hold AS (
  SELECT
    page_number,
    ml_generate_text_llm_result AS policy_text
  FROM
    ML.GENERATE_TEXT( MODEL `{project_id}.${dataset_id}.generate_text`,
      (
      SELECT
        'Parse the text in this image and return its value:' || uri AS prompt, CAST   (REGEXP_EXTRACT(uri, r'^gs\:\/\/customer-service-policy-us/images/Cymbal Sports Customer Service Policy_Page_([0-9]{2})\.jpg$') AS INT64) AS page_number,
      FROM
        `{project_id}.${dataset_id}.customer_service_policy`),
      STRUCT(1600 AS max_output_tokens,
        0.2 AS temperature,
        40 AS top_k,
        0.3 AS top_p,
        TRUE AS flatten_json_output )))

SELECT ARRAY_TO_STRING(ARRAY(SELECT TRIM(policy_text, "Internal Only For use by Cymbal Sports employees only") FROM hold WHERE page_number > 2 ORDER BY page_number)," ") AS service_policy_text, 1.0 AS version_number
