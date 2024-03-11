CREATE OR REPLACE TABLE `${project_id}.${dataset_id}.complete_service_policy`
AS
with hold AS(
  SELECT
    REGEXP_REPLACE(REGEXP_REPLACE(JSON_VALUE(ml_annotate_image_result.full_text_annotation.text), r'\n', ' '), r'•|●', '') AS text_content,
    CAST(REGEXP_EXTRACT(uri, r'^gs\:\/\/customer-service-policy-us/images/Cymbal Sports Customer Service Policy_Page_([0-9]{2})\.jpg$') AS INT64) AS page_number,
    *
  FROM
    ML.ANNOTATE_IMAGE(MODEL `${project_id}.${dataset_id}.vision_ai`,
      TABLE `${project_id}.${dataset_id}.customer_service_policy`,
      STRUCT(['DOCUMENT_TEXT_DETECTION'] AS vision_features)) reviews)

SELECT ARRAY_TO_STRING(ARRAY(SELECT TRIM(text_content, "Internal Only For use by Cymbal Sports employees only") FROM hold WHERE page_number > 2 ORDER BY page_number)," ") AS service_policy_text, 1.0 AS version_number

