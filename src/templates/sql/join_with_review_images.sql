CREATE OR REPLACE TABLE `${project_id}.${dataset_id}.raw_reviews_joined`
AS

WITH the_join AS(
  SELECT
    reviews.*,
    orders.order_id AS order_id,
    orders.created_at AS created_at
  FROM
    `${project_id}.${dataset_id}.raw_reviews` reviews
  LEFT JOIN
    `${project_id}.${dataset_id}.order_items` orders
  ON
    reviews.user_id = orders.user_id
    AND reviews.product_id = CAST(orders.product_id AS STRING)),

hold AS(
  SELECT
    the_join.review_id,
    the_join.order_id,
    the_join.product_id,
    ARRAY_AGG(STRUCT(
        created_at,
        user_id,
        name,
        review_rating,
        review_text)
    ORDER BY
      created_at DESC
    LIMIT
      1) x
  FROM
    the_join
  GROUP BY
    review_id,
    order_id,
    product_id),

output AS (
  SELECT
    hold.review_id,
    hold.order_id,
    hold.user_id,
    product_id,
    name,
    review_rating,
    review_text
  FROM
    hold,
    UNNEST(hold.x))

SELECT
  output.*,
  uri
FROM
  output
LEFT JOIN
  `${project_id}.${dataset_id}.${object_table}` ON output.review_id = REGEXP_EXTRACT(uri, r'.*([0-9]{3})\.png$')
