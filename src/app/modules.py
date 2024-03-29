# This file will get executed when the function is executed
# import google.cloud.storage as gcs
import json
import os
import vertexai
import pandas_gbq

from google.cloud import pubsub_v1, storage as gcs
from vertexai import generative_models
from vertexai.generative_models import GenerativeModel, Part
from vertexai.language_models import TextEmbeddingModel
# from vertexai.vision_models import MultiModalEmbeddingModel

# Change the values of the 4 lines below to match your requirements

# Project ID
project_id = os.environ['PROJECT_ID']
# Pub/Sub Topic ID for prompt
prompt_pubsub_topic_id = "gemini-multimodal-demo-refunds-prompts"
# Pub/Sub Topic ID for response
response_pubsub_topic_id = "gemini-multimodal-demo-refunds-responses"
# Pub/Sub Topic ID for continuous query refunds table
refund_pubsub_topic_id = "gemini-multimodal-demo-refunds-refunds"

# GCP region
location = os.environ['REGION']

publisher = pubsub_v1.PublisherClient()
prompt_topic_path = publisher.topic_path(project_id, prompt_pubsub_topic_id)
response_topic_path = publisher.topic_path(
    project_id, response_pubsub_topic_id)
refund_pubsub_topic_path = publisher.topic_path(
    project_id, refund_pubsub_topic_id)
blob_path = "cymbal-sports/review-images/uploads"

vertexai.init(project=project_id,
              location=location)


def get_text_embeddings(text_input):
    text_embed_model = TextEmbeddingModel.from_pretrained(
        "textembedding-gecko@003")
    text_embeddings = text_embed_model.get_embeddings([text_input])
    text_embeddings = text_embed_model.get_embeddings([text_input])
    for embedding in text_embeddings:
        vector = embedding.values
        return vector


# def get_embeddings(prompt, order_number, dimension: int = 1408):
#     embed_model = MultiModalEmbeddingModel.from_pretrained(
#         "multimodalembedding")
#     if prompt[1] is None:
#         text_embed_output = get_text_embeddings(prompt[0])
#         return text_embed_output
#     else:
#         print(f"Prompt input to the embedding model is: {prompt[1]}")
#         output_bucket_name = os.environ['OUTPUT_BUCKET']
#         image_to_embed_uri = f"gs:///{output_bucket_name}/{blob_path}/{order_number}_refund_request.png"
#         print(f"Review image URI: {image_to_embed_uri}")
#         text_embed_output = get_text_embeddings(prompt[0])
#         image = Image.load_from_file(image_to_embed_uri)
#         image_embedding = embed_model.get_embeddings(
#             image=image,
#             dimension=dimension
#         )
#         image_embed_output = image_embedding.image_embedding
#         return [text_embed_output, image_embed_output]


def products_in_order(order_id):
    project_id = os.environ['PROJECT_ID']

    request_order_id = order_id
    sql = f"""
        SELECT
            product_id,
            products.name AS product_name,
        FROM
            `cymbal_sports.order_items` orders
        JOIN
            `cymbal_sports.products` products
        ON
            orders.product_id = products.id
        WHERE
            order_id = "{request_order_id}"
        """

    variables_df = pandas_gbq.read_gbq(sql, project_id=project_id)
    return variables_df


def get_required_inputs(email, order_id, product_id):
    project_id = os.environ['PROJECT_ID']
    regexp_inventory_uri = "r'^gs.*([0-9]{3}).png$'"
    sql = f"""
        WITH hold AS(
            SELECT
                orders.returned AS orders_returned,
                order_details.sale_price AS sale_price,
                order_details.ship_date AS shipping_date,
                product_id,
                uri,
                user_id,
                order_id,
                products.name AS product_name,
                users.email AS email
            FROM (
                    SELECT
                        COUNT(DISTINCT order_id) AS returned,
                        user_id
                    FROM
                        `cymbal_sports.order_items` orders
                    WHERE
                        orders.created_at BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
                        AND CURRENT_TIMESTAMP()
                    GROUP BY
                        user_id
                ) orders,
                (
                    SELECT
                        sale_price,
                        shipped_at AS ship_date,
                        product_id,
                        order_id
                    FROM
                        `cymbal_sports.order_items`
                    WHERE
                        order_id = "{order_id}"
                        AND product_id = "{product_id}"
                ) AS order_details
                JOIN
                    `cymbal_sports.inventory_images` inventory
                    ON product_id = REGEXP_EXTRACT(inventory.uri, {regexp_inventory_uri})
                JOIN
                    `cymbal_sports.products` products
                    ON products.id = order_details.product_id
                JOIN
                    `cymbal_sports.users` users
                    ON users.id = orders.user_id
                WHERE
                    email = "{email}"
                ),

        policy_version AS(
        SELECT
            MAX(version_number) AS latest
        FROM
            `cymbal_sports.complete_service_policy` )

        SELECT
        IF(
            (orders_returned < 50
                AND sale_price < 50
                AND shipping_date > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
            ),
            "True", "False") AS eligible,
        product_id,
        service_policy_text,
        policy_version.latest AS policy_version,
        uri AS inventory_image_uri,
        hold.user_id AS user_id,
        hold.email AS email,
        sale_price,
        product_name,
        hold.order_id AS order_id,
        FROM
        hold,
        `cymbal_sports.complete_service_policy` service_policy,
        policy_version
        WHERE
        service_policy.version_number = policy_version.latest
    """
    variables_df = pandas_gbq.read_gbq(sql, project_id=project_id)
    return variables_df


def upload_to_gcs(image_path, destination_blob_name):
    output_bucket_name = os.environ['OUTPUT_BUCKET']
    client = gcs.Client()
    bucket = client.bucket(output_bucket_name)
    blob_name = f"{blob_path}/{destination_blob_name}"
    blob = bucket.blob(blob_name)
    blob.upload_from_filename(image_path, client=client)
    print(f"gs://{output_bucket_name}/{blob_name}")
    return (f"gs://{output_bucket_name}/{blob_name}")


def get_response(model_version, prompt):
    model = GenerativeModel(model_version)
    # These parameters can be modified to better suit your needs. Check out
    # the documentation to learn more:
    # https://cloud.google.com/vertex-ai/docs/generative-ai/model-reference/text#request_body
    safety_settings = {
        generative_models.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: generative_models.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
        generative_models.HarmCategory.HARM_CATEGORY_HARASSMENT: generative_models.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
        generative_models.HarmCategory.HARM_CATEGORY_HATE_SPEECH: generative_models.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
        generative_models.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: generative_models.HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
    }

    generation_config = {
        "max_output_tokens": 2048,
        "temperature": 0.7,
        "top_p": 1,
        "top_k": 32
    }

    output = model.generate_content(prompt,
                                    generation_config=generation_config,
                                    stream=False,
                                    safety_settings=safety_settings
                                    )

    return output


def publish_prompt_pubsub(
        feedback_embedding,
        prompt,
        text_embed,
        request_image_uri,
        model_version,
        policy_version,
        product_id,
        order_id,
        user_id):
    text_embed = json.dumps(text_embed)
    feedback_embedding = json.dumps(feedback_embedding)
    # image_embed = json.dumps(image_embed)
    dict = {"feedback_embedding": feedback_embedding,
            "prompt": prompt,
            "prompt_embedding": text_embed,
            "request_image_uri": request_image_uri,
            "model_version": model_version,
            "policy_version": policy_version,
            "user_id": user_id,
            "order_id": order_id,
            "product_id": product_id}
    data_string = json.dumps(dict)
    data = data_string.encode("utf-8")
    future = publisher.publish(prompt_topic_path, data)
    return (future)


def publish_response_pubsub(
        order_id,
        product_id,
        user_id,
        response,
        safety_attributes,
        response_embedding):
    response_embedding = json.dumps(response_embedding)
    safety_attributes = json.dumps(safety_attributes)
    dict = {
        "order_id": order_id,
        "product_id": product_id,
        "user_id": user_id,
        "response": response,
        "safety_attributes": safety_attributes,
        "response_embedding": response_embedding}
    data_string = json.dumps(dict)
    data = data_string.encode("utf-8")
    future = publisher.publish(response_topic_path, data)
    return (future)


def publish_refund_pubsub(
        product_id,
        product_name,
        refund_amount,
        order_id,
        email):
    dict = {"product_id": product_id,
            "product_name": product_name,
            "refund_amount": refund_amount,
            "order_id": order_id,
            "email": email}
    data_string = json.dumps(dict)
    data = data_string.encode("utf-8")
    future = publisher.publish(refund_pubsub_topic_path, data)
    return (future)


def call_llm(inputs,
             form_fields):
    policy = inputs["service_policy_text"][0]
    inventory_image_uri = str(inputs["inventory_image_uri"][0])
    policy_version = inputs["policy_version"][0]
    product_id = inputs["product_id"][0]
    # email = form_fields[0]
    order_number = str(form_fields[1])
    review_text = form_fields[2]

    if inventory_image_uri is None:
        inventory_image = None
    else:
        inventory_image = Part.from_uri(
            inventory_image_uri, mime_type="image/png")

    output_bucket_name = os.environ['OUTPUT_BUCKET']

    review_image_uri = f"gs://{output_bucket_name}/{blob_path}/{order_number}_refund_request.png"
    review_image = Part.from_uri(review_image_uri, mime_type="image/png")

    context = f"""Provide the following response as either a "yes" or a "no".
You are an expert customer service agent for an eCommerce sporting goods retailer named Cymbal Sports. You are intimately familiar with the company's customer service policy, which is: {policy}.

You were taught in your training that a product is defective if it has any of the following: Ripped seams, uneven stitching, missing buttons, broken zippers, misaligned patterns, incorrect sizing, holes, tears, snags, pilling, fabric weakness causing unexpected wears, significant fading or bleeding beyond what's normal for the fabric type, has mismatched dye lots in a single item, or if it starts to develop mold.

One of your customers has submitted a defective product claim. Your supervisor has asked you to review the information from the customer and determine if the item is defective. If so, the issue resolution is this purchase can be refunded without requiring a return.
Consider the review text and review image to understand the customer's experience.
If it is available, The inventory image for the product they purchased is the second image.
If it is available, the review text is {review_text}.
If it is available, the review image is the first image.

Consider the review text and compare the review image to the inventory image and determine if the product is damaged or defective.

Your answer should only either be "yes" or "no"
    """

    model_version = "gemini-1.0-pro-vision"

    if review_image is None:
        prompt = [context, None, inventory_image]
        # embed_inputs = [context, None, inventory_image_uri]
    else:
        prompt = [context, review_image, inventory_image]
        # embed_inputs = [context, review_image_uri, inventory_image_uri]

    user_id = inputs["user_id"][0]
    # email = inputs["email"][0]
    order_id = inputs["order_id"][0]
    prompt_embeddings = get_text_embeddings(context)
    feedback_embedding = get_text_embeddings(review_text)

    publish_prompt_pubsub(
        feedback_embedding=feedback_embedding,
        prompt=context,
        text_embed=prompt_embeddings[0],
        request_image_uri=review_image_uri,
        model_version=model_version,
        policy_version=policy_version,
        product_id=product_id,
        order_id=order_id,
        user_id=user_id
    )

    output = get_response(model_version, prompt)

    output_dict = output.to_dict()
    safety_ratings = output_dict["candidates"][0]["safety_ratings"]
    model_response = output.text
    response_embed = get_text_embeddings(model_response)
    publish_response_pubsub(
        order_id=order_id,
        product_id=product_id,
        user_id=user_id,
        response=model_response,
        safety_attributes=safety_ratings,
        response_embedding=response_embed)
    return model_response
