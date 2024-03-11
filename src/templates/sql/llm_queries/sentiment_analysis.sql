-- CREATE OR REPLACE TABLE
--   `${project_id}.cymbal_sports.llm_cleaned_reviews` AS
SELECT
  original.*,
  ml_generate_text_llm_result AS review_sentiment
FROM
  ML.GENERATE_TEXT( MODEL `${project_id}.cymbal_sports.generate_text`,
    (
    SELECT
      review_id,
      ('Determine the sentiment of this review: ' || review_text || 'Return one of the three words as the response: "positive", "neutral", "negative"' ) AS prompt
    FROM
      `cymbal_sports.reviews_joined_translated`),
    STRUCT( 800 AS max_output_tokens,
      0.3 AS temperature,
      40 AS top_k,
      0.8 AS top_p,
      TRUE AS flatten_json_output ) )
LEFT JOIN
  `${project_id}.cymbal_sports.reviews_joined_translated` original
USING
  (review_id)
