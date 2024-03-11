  #Gemini as a customer service agent
WITH
  hold AS (
  SELECT
    PARSE_JSON(`${project_id}.cymbal_sports_lineage.analyze_data` (review_id)) AS response
  FROM
    `${project_id}.cymbal_sports.cleaned_reviews`
  WHERE
    sentiment = "negative"
    AND uri IS NOT NULL )

SELECT
  STRING(response.issue_resolution) AS issue_resolution,
  STRING(response.response_user_language) AS email_user_language,
  STRING(response.response_translated) AS email_translated
FROM
  hold
