--Model Example
CREATE OR REPLACE MODEL
  `${project_id}.${marketing_dataset_id}.customer_segment_clustering`
  OPTIONS(
    MODEL_TYPE = 'KMEANS', -- model name
    NUM_CLUSTERS = 3, -- how many clusters to create
    KMEANS_INIT_METHOD = 'KMEANS++',
    STANDARDIZE_FEATURES = TRUE -- note: normalization taking place to scale the range of independent variables (each feature contributes proportionately to the final distance)
  )
  AS (
    SELECT
      * EXCEPT (user_id)
    FROM (
      SELECT
        user_id,
        DATE_DIFF(CURRENT_DATE(), CAST(MAX(order_created_date) as DATE), day) as days_since_order, ---RECENCY
        COUNT(DISTINCT order_id) as count_orders, --FREQUENCY
        AVG(sale_price) as avg_spend --MONETARY
      FROM (
        SELECT
          user_id,
          order_id,
          sale_price,
          created_at as order_created_date
        FROM
          `${project_id}.${infra_dataset_id}.order_items`
        WHERE
          created_at BETWEEN TIMESTAMP('2024-03-01 00:00:00')
          AND TIMESTAMP('2024-03-31 00:00:00')
      )
      GROUP BY user_id
    )
  )
;
