-- CREATE OR REPLACE TABLE `${project_id}.${dataset_id}.llm_reviews_joined_translated`
-- AS
SELECT
  review_text AS review_text_raw,
  ml_generate_text_llm_result AS review_text,
  * EXCEPT (review_text, ml_generate_text_llm_result, ml_generate_text_status),
FROM
  ML.GENERATE_TEXT( MODEL `${project_id}.${dataset_id}.generate_text`,
    (
    SELECT
      *,
      ('Translate this text into English: ' || review_text || ' .') AS prompt
    FROM
      `${project_id}.${dataset_id}.raw_reviews_joined`),
    STRUCT( 800 AS max_output_tokens,
      0.8 AS temperature,
      40 AS top_k,
      0.8 AS top_p,
      TRUE AS flatten_json_output ) )
