CREATE OR REPLACE TABLE
`${project_id}.${dataset_id}.raw_reviews_joined`
AS
SELECT
  reviews.*,
  uri
FROM
  `${project_id}.${dataset_id}.${raw_reviews_table}` reviews
LEFT JOIN
  `${project_id}.${dataset_id}.${object_table}` ON reviews.review_id = REGEXP_EXTRACT(uri, r'.*([0-9]{3})\.png$')
