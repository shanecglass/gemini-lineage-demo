CREATE OR REPLACE TABLE `${project_id}.${lineage_dataset_id}.cleaned_responses`
AS

WITH parser AS (
  SELECT
    * EXCEPT(data),
    PARSE_JSON(data, wide_number_mode=>'round') AS data
  FROM
    `${project_id}.${lineage_dataset_id}.responses`
  ),

cleaning AS (
  SELECT
    TO_JSON(data) AS original_message,
    publish_time,
    JSON_VALUE(data.review_id) AS review_id,
    JSON_VALUE(data.response) AS response,
    (data.safety_attributes) AS safety_attributes,
    message_id,
    subscription_name,
    attributes,
    CONCAT("[",TRIM(JSON_VALUE(data.embedding),"[]"),"]") AS response_embedding,
  FROM
    parser
),

hold AS(
  SELECT
    * EXCEPT(response_embedding),
    ROUND(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), publish_time, MINUTE)/60,2) AS hours_since_prompt,
    response_embedding
  FROM
    cleaning
  WHERE
    response_embedding IS NOT NULL
)

SELECT * FROM hold
