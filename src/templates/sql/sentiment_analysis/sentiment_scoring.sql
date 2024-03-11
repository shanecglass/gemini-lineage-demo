CREATE OR REPLACE TABLE `${project_id}.cymbal_sports.cleaned_reviews`
AS
SELECT
  * EXCEPT (text_content, ml_understand_text_result, ml_understand_text_status),
  CASE
    WHEN CAST(JSON_VALUE(ml_understand_text_result, '$.document_sentiment.score') AS FLOAT64) > 0 THEN "positive"
    WHEN CAST(JSON_VALUE(ml_understand_text_result, '$.document_sentiment.score') AS FLOAT64) < 0 THEN "negative"
    WHEN CAST(JSON_VALUE(ml_understand_text_result, '$.document_sentiment.score') AS FLOAT64) = 0 THEN "neutral"
    ELSE "unknown"
  END AS sentiment,
  CAST(JSON_VALUE(ml_understand_text_result, '$.document_sentiment.magnitude') AS FLOAT64) AS sentiment_magnitude,
  CAST(JSON_VALUE(ml_understand_text_result, '$.document_sentiment.score') AS FLOAT64) AS sentiment_score,
FROM
  ML.UNDERSTAND_TEXT(MODEL `${project_id}.cymbal_sports.nlp`,
    (
    SELECT
      *,
      review_text AS text_content
    FROM
      `cymbal_sports.reviews_joined_translated`),
    STRUCT('ANALYZE_SENTIMENT' AS nlu_option)
  )
