CREATE OR REPLACE TABLE `${project_id}.${marketing_dataset_id}.customer_personas`
AS
with hold AS(
  SELECT centroid AS cluster, ml_generate_text_llm_result AS persona
  FROM ML.GENERATE_TEXT(
    MODEL `${project_id}.${infra_dataset_id}.generate_text`,
    (
      with clusters AS(
        SELECT
        centroid_id as centroid,
        avg_spend as average_spend,
        count_orders as count_of_orders,
        days_since_order
        FROM (
          SELECT centroid_id, feature, ROUND(numerical_value, 2) as value
          FROM ML.CENTROIDS(MODEL `${project_id}.${marketing_dataset_id}.customer_segment_clustering`)
        )
        PIVOT (
          SUM(value)
          FOR feature IN ('avg_spend',  'count_orders', 'days_since_order')
        )
        ORDER BY centroid_id
      )

      SELECT
        'Provide the following response in a JSON format. Pretend you are a creative strategist, given the following clusters come up with a creative persona_title and persona_description of these personas for each of these clusters' || ' ' || clusters.centroid || ', Average Spend $' || clusters.average_spend || ', Count of orders per person ' || clusters.count_of_orders || ', Days since last order ' || clusters.days_since_order || 'The parent fields are persona_title and persona_description. Parent fields should be lower cased. There are no child fields. Do not include JSON decorator. This is an example of an output that is correctly formatted:{{"persona_title": "The Frequent Flyer", "response_email": "A loyal customer who makes multiple orders per year. They tend to order frequently and spend a lot of money when they do order. They are highly engaged with our brand."}}' AS prompt,
        centroid
      FROM
        clusters
    ),
    -- See the BigQuery 'Generate Text' docs to better understand how changing these inputs will impact your results: https://cloud.google.com/bigquery/docs/generate-text#generate_text
      STRUCT(
        800 AS max_output_tokens,
        0.8 AS temperature,
        40 AS top_k,
        0.8 AS top_p,
        TRUE AS flatten_json_output
      )
    )
)
SELECT
  cluster, TRIM(JSON_QUERY(persona, '$.persona_title'),'"') as persona_title, TRIM(JSON_QUERY(persona, '$.persona_description'),'"') as persona_description
  FROM hold
;
