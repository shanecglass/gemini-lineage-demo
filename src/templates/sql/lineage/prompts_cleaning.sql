CREATE OR REPLACE TABLE `${project_id}.${lineage_dataset_id}.cleaned_prompts`
AS

with parser AS (
  SELECT
    * EXCEPT(data),
    PARSE_JSON(data, wide_number_mode=>'round') AS data
  FROM
    `${project_id}.${lineage_dataset_id}.prompts`
),

cleaning AS (
  SELECT
    data AS original_message,
    publish_time,
    JSON_VALUE(data.review_id) AS review_id,
    TRIM(JSON_VALUE(data.prompt)) AS prompt,
    JSON_VALUE(data.model_version) AS model_version,
    JSON_VALUE(data.policy_version) AS policy_version,
    subscription_name,
    attributes,
    CONCAT("[",TRIM(JSON_VALUE(data.text_embed),"[]"),"]") AS prompt_embedding,
    CONCAT("[",TRIM(JSON_VALUE(data.review_embed),"[]"),"]") AS review_embedding,
    CONCAT("[",TRIM(JSON_VALUE(data.image_embed),"[]"),"]") AS image_embedding,
  FROM
    parser
),

hold AS (
  SELECT
    * EXCEPT(prompt_embedding, review_embedding, image_embedding),
    ROUND(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), publish_time, MINUTE)/60,2) AS hours_since_prompt,
    prompt_embedding,
    review_embedding,
    image_embedding
  FROM
    cleaning
  WHERE
    prompt_embedding IS NOT NULL
)

SELECT * FROM hold
