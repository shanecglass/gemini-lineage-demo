CREATE OR REPLACE TABLE `${PROJECT_ID}.${DATASET_ID}.reviews_joined_translated`
AS
SELECT
  reviews.* EXCEPT (review_text, text_content,ml_translate_result, ml_translate_status),
  review_text AS review_text_raw,
  REGEXP_REPLACE(TRIM(JSON_VALUE(ml_translate_result, '$$.translations[0].translated_text')), r'([a-zA-Z0-9\s]*)&#39;([a-zA-Z0-9\s]*)', "\\1'\\2") AS review_text,
  language_name_en AS review_language,
FROM
  ML.TRANSLATE(MODEL `${PROJECT_ID}.${DATASET_ID}.translate`,
    (
    SELECT
      *,
      review_text AS text_content
    FROM
     `${PROJECT_ID}.${DATASET_ID}.raw_reviews_joined`),
    STRUCT('translate_text' AS translate_mode, 'en' AS target_language_code)
  ) reviews
LEFT JOIN
  `${PROJECT_ID}.${DATASET_ID}.iso_639_codes` iso ON TRIM(JSON_VALUE(reviews.ml_translate_result, '$$.translations[0].detected_language_code')) = iso.iso_639_1
