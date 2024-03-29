CREATE OR REPLACE TEMP TABLE hold
AS

with subset AS (
  SELECT
    user_id,
    order_id,
    SUM(sale_price) AS total_order_price,
    created_at as order_created_date
  FROM
    `${project_id}.${infra_dataset_id}.order_items`
  WHERE
    created_at BETWEEN TIMESTAMP("2024-03-01 00:00:00")
    AND TIMESTAMP("2024-03-31 00:00:00")
    AND user_id = "82537"
  GROUP BY
    order_id, user_id, created_at
),

prep AS (
  SELECT
    user_id,
    DATE_DIFF(CURRENT_DATE(), CAST(MAX(order_created_date) as DATE), day) as days_since_order, #RECENCY
    COUNT(DISTINCT order_id) as count_orders, #FREQUENCY
    AVG(total_order_price) as avg_spend #MONETARY
  FROM
    subset
  GROUP BY
    user_id
),

products AS(
  SELECT
    product_1.name AS product_1_name,
    product_1.description AS product_1_description,
    product_2.name AS product_2_name,
    product_2.description AS product_2_description
  FROM (
    SELECT
      ARRAY_AGG((SELECT AS STRUCT name, description FROM `${project_id}.${infra_dataset_id}.products` WHERE name = "Swift Performance Tee" )) AS product_1_array,
      ARRAY_AGG((SELECT AS STRUCT name, description FROM `${project_id}.${infra_dataset_id}.products` WHERE name = "Ascend Water Bottle" )) AS product_2_array
    FROM
      `${project_id}.${infra_dataset_id}.products`),
    UNNEST(product_1_array) product_1,
    UNNEST(product_2_array) product_2
)


SELECT
  cluster.* EXCEPT(nearest_centroids_distance), persona.* EXCEPT (cluster), user.age AS age, user.state AS state, user.country AS country, products.*, first_name, last_name, user.email AS user_email
  FROM
    ML.PREDICT( MODEL `${project_id}.${marketing_dataset_id}.customer_segment_clustering`,
      (SELECT
        *
      FROM
        prep
      )
    ) cluster, products
  JOIN
    `${project_id}.${marketing_dataset_id}.customer_personas` persona ON cluster.centroid_id = persona.cluster
  JOIN
    `${project_id}.${infra_dataset_id}.users` user ON cluster.user_id = user.id
  LIMIT 1
;

EXECUTE IMMEDIATE FORMAT(
  """
CREATE OR REPLACE TEMP TABLE product_description_1
AS
SELECT
    centroid_id AS cluster,
    persona_title,
    ml_generate_text_rai_result,
    ml_generate_text_llm_result as output,
    uri
  FROM
    ML.GENERATE_TEXT(
      MODEL `${project_id}.${infra_dataset_id}.generate_vision_pro`,
      TABLE `${project_id}.${infra_dataset_id}.inventory_images`,
      STRUCT(
        '%s' AS prompt,
        2048 AS max_output_tokens,
        1 AS temperature,
        40 AS top_k,
        1 AS top_p,
        TRUE AS flatten_json_output
      )
    ) output, hold
    WHERE
      REGEXP_EXTRACT(uri, r'^gs.*([0-9]{3}).png$') = '100'
  ;
  """,

(SELECT
  'You are a marketing expert for Cymbal Sports, an eCommerce sporting goods retailer. Rewrite the product description for the product in this image. The new description should be written to appeal to a customer named ' || hold.first_name || ' ' || hold.last_name || ' who is a ' || hold.age || ' year old male who lives in state: ' || hold.state || ' and country ' || hold.country || '. Their customer persona_name is ' || hold.persona_title || ' . Their persona_description is: ' || hold.persona_description || ' The original product description is ' || hold.product_1_description
FROM
  hold)
);

SELECT JSON_QUERY(TRIM(ml_generate_text_llm_result), '$.email_english') AS email_english, email.* EXCEPT(ml_generate_text_llm_result),
  FROM ML.GENERATE_TEXT(
    MODEL `${project_id}.${infra_dataset_id}.generate_text`,
    (SELECT hold.*, 'Provide the following response in a valid JSON format. You are an email marketing expert for Cymbal Sports, an eCommerce sporting goods retailer. You are writing a message to a customer named ' || hold.first_name || ' ' || hold.last_name || ' who is a ' || hold.age || ' year old male who lives in state: ' || hold.state || ' and country ' || hold.country || '. Their customer persona_name is ' || hold.persona_title || ' . Their persona_description is: ' || hold.persona_description || ' Our user_research shows that ' || hold.first_name || ' definitely enjoys yoga and probably has a daughter who plays golf but it is impossible to know for sure. Write an email apologizing for the issues he experienced after purchasing the Zenith Yoga Mat and include a discount code for 10% off his next purchase. The email should be written in the style of a Texas high school football coach named Coach Tough apologizing for the first time in his life. The email should suggest the product_name_1: ' || hold.product_1_name || ' and product_name_2: ' || hold.product_2_name || ' for his next purchase. The original_description_1 for product_1_name is: ' || product_description_1.output || ' and original_description_2 for product_2_name is: ' || hold.product_2_description || '. Rewrite original_description_1 and original_description_2 to best appeal to the customer based on their age, persona_title, persona_description, where they live, and the user_research you have about them. Include this image in how you describe the' || hold.product_1_name || ' as well. Do not explicitly mention the customer having a teenage daughter. If the user country is not United States translate the message into Portuguese. The email should address the customer with "Listen up Champ. Coach Tough is talking. Alright ' || hold.first_name || '". The parent fields are email_english and email_portuguese. Parent fields should be lower cased. There are no child fields. Do not include JSON decorator. This is an example of an output that is correctly formatted: {"email_english": "Dear customer_name, We sincerely apologize for the issue you experienced with your previous product. At Company Name, customer satisfaction is very important to us, and we clearly fell short of our standards this time. To make things right, we would like to offer you a 10% discount on your next purchase. Please use code FIXIT10 at checkout. We understand this might not fully resolve the inconvenience, but we hope it is a start. Additionally, here are a few new products we think you might like: New Product 1 - Brief description highlighting its benefits New Product 2 - Brief description highlighting its benefits Please let us know if there is anything else we can do to assist you. We appreciate your understanding and continued business. Sincerely, Your Name Company Name", "email_translated": "Prezado(a) Nome do Cliente,Pedimos sinceras desculpas pelo problema que você teve com seu produto anterior. Na Nome da Empresa, a satisfação do cliente é muito importante para nós, e claramente ficamos abaixo dos nossos padrões dessa vez. Para corrigir isso, gostaríamos de oferecer a você um desconto de 10% em sua próxima compra. Por favor, use o código FIXIT10 na finalização da compra. Entendemos que isso pode não resolver totalmente o inconveniente, mas esperamos que seja um começo. Além disso, aqui estão alguns novos produtos que achamos que você possa gostar: Novo Produto 1 - Breve descrição destacando seus benefícios Novo Produto 2 - Breve descrição destacando seus benefícios Por favor, entre em contato se houver mais alguma coisa que possamos fazer para ajudá-lo. Agradecemos a sua compreensão e a continuidade dos negócios. Atenciosamente, Seu Nome Nome da Empresa"}' as prompt FROM hold, product_description_1),
    STRUCT(
        4000 AS max_output_tokens,
        1 AS temperature,
        40 AS top_k,
        1 AS top_p,
        TRUE AS flatten_json_output
      )
  ) email


