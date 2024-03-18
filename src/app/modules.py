# This file will get executed when the function is executed
import google.cloud.storage as gcs
import json
import json_repair
import os
import vertexai
import pandas_gbq

from google.cloud import pubsub_v1
from vertexai import generative_models
from vertexai.generative_models import GenerativeModel, Image, Part
from vertexai.language_models import TextEmbeddingModel
from vertexai.vision_models import MultiModalEmbeddingModel


# Change the values of the 4 lines below to match your requirements

# Project ID
project_id = os.environ['PROJECT_ID']
# Pub/Sub Topic ID for prompt
prompt_pubsub_topic_id = "gemini-multimodal-demo-prompts"
# Pub/Sub Topic ID for response
response_pubsub_topic_id = "gemini-multimodal-demo-responses"
# GCP region
location = os.environ['REGION']

publisher = pubsub_v1.PublisherClient()
prompt_topic_path = publisher.topic_path(project_id, prompt_pubsub_topic_id)
response_topic_path = publisher.topic_path(
    project_id, response_pubsub_topic_id)

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


def get_embeddings(prompt, dimension: int = 1408):
    embed_model = MultiModalEmbeddingModel.from_pretrained(
        "multimodalembedding")
    if prompt[1] is None:
        text_embed_output = get_text_embeddings(prompt[0])
        return text_embed_output
    else:
        text_embed_output = get_text_embeddings(prompt[0])
        image = Image.load_from_file(prompt[1])
        image_embedding = embed_model.get_embeddings(
            image=image,
            dimension=dimension
        )
        image_embed_output = image_embedding.image_embedding
        return [text_embed_output, image_embed_output]


def get_required_inputs(email, order_id):
    project_id = os.environ['PROJECT_ID']
    regexp_inventory_uri = "r'^gs.*([0-9]{3}).png$'"
    sql = f"""
        with hold AS(
        SELECT
            orders.returned AS orders_returned,
            order_details.order_total AS order_total,
            order_details.ship_date AS shipping_date,
            product_id,
            uri
            FROM (
                SELECT
                    COUNT(DISTINCT order_id) AS returned
                FROM
                    `cymbal_sports.users` users
                JOIN
                    `cymbal_sports.order_items` orders
                    ON
                        users.id = orders.user_id
                WHERE
                    email = "{email}"
                    AND orders.created_at BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY) AND CURRENT_TIMESTAMP()
                    AND status = "Returned"
            ) orders,
            (
                SELECT
                    SUM(sale_price) AS order_total,
                    shipped_at AS ship_date,
                    product_id
                FROM
                    `cymbal_sports.order_items`
                WHERE
                    order_id = "{order_id}"
                GROUP BY
                    order_id, shipped_at, product_id
            ) AS order_details
            JOIN `cymbal_sports.inventory_images` inventory
                    ON product_id = REGEXP_EXTRACT(inventory.uri, {regexp_inventory_uri})
        ),

        policy_version AS(
        SELECT MAX(version_number) AS latest
        FROM `cymbal_sports.complete_service_policy`
        )

        SELECT
            IF((orders_returned < 5 AND order_total < 50 AND shipping_date > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)), true, false) AS eligible,
            product_id,
            service_policy_text,
            policy_version.latest AS policy_version,
            uri AS inventory_image_uri
        FROM hold, `cymbal_sports.complete_service_policy` service_policy, policy_version
        WHERE service_policy.version_number = policy_version.latest
        """
    variables_df = pandas_gbq.read_gbq(sql, project_id=project_id)
    return variables_df


def upload_to_gcs(source_file_name, destination_blob_name):
    output_bucket_name = os.environ.get["OUTPUT_BUCKET"]
    client = gcs.Client()
    bucket = client.bucket(output_bucket_name)
    blob = bucket.blob(f"review-images/{destination_blob_name}")
    blob.upload_from_filename(source_file_name)
    print(f"gs://{output_bucket_name}/{destination_blob_name}")
    return f"gs://{output_bucket_name}/{destination_blob_name}"


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
        review_embeddings,
        prompt,
        text_embed,
        image_embed,
        model_version,
        policy_version):
    text_embed = json.dumps(text_embed)
    review_embeddings = json.dumps(review_embeddings)
    image_embed = json.dumps(image_embed)
    dict = {"review_embedding": review_embeddings,
            "prompt": prompt,
            "prompt_embedding": text_embed,
            "image_embedding": image_embed,
            "model_version": model_version,
            "policy_version": policy_version}
    data_string = json.dumps(dict)
    data = data_string.encode("utf-8")
    future = publisher.publish(prompt_topic_path, data)
    return (future)


def publish_response_pubsub(
        response_text,
        safety_attributes,
        embedding):
    embedding = json.dumps(embedding)
    safety_attributes = json.dumps(safety_attributes)
    dict = {
        "response": response_text,
        "safety_attributes": safety_attributes,
        "response_embedding": embedding}
    data_string = json.dumps(dict)
    data = data_string.encode("utf-8")
    future = publisher.publish(response_topic_path, data)
    return (future)


def call_llm(inputs,
             form_fields,
             review_image_path):
    policy = inputs["service_policy_text"][0]
    inventory_image_uri = str(inputs["inventory_image_uri"][0])
    policy_version = inputs["policy_version"][0]
    product_id = inputs["product_id"][0]

    if inventory_image_uri is None:
        inventory_image = None
    else:
        inventory_image = Part.from_uri(
            inventory_image_uri, mime_type="image/jpeg")

    review_text = form_fields[2]
    order_number = form_fields[1]
    # email = form_fields[0]

    review_image_uri = upload_to_gcs(
        review_image_path, f"{order_number}_{product_id}.png")
    review_image = Image.load_from_file(review_image_path)

    context = f"""
                Provide the following response in a JSON format.
                You are an expert customer service agent for an eCommerce sporting goods retailer named Cymbal Sports.
                One of your customers received a defective item. Your supervisor has already determined that the issue resolution is this purchase can be refunded without requiring a return.
                Consider the review text and review image to understand the customer's experience.
                If it is available, The inventory image for the product they purchased is {inventory_image}.
                If it is available, the review text is {review_text}.
                If it is available, the review image is {review_image}.
                The customer service policy is: {policy}
                Explain exactly what the problem is and the issue resolution.

                Then, write an email to the user explaining how you are going to resolve their issue.
                The email should be written in the style of a Texas high school football coach who is admitting he made a mistake for the first time ever.

                The parent fields are issue_resolution and response_email.
                Parent fields should be lower cased.
                There are no child fields.
                Do not include JSON decorator.

                This is an example of an output that is correctly formatted:
                {{
                    "issue_resolution": "This item did not meet our quality standards. Offer the customer the option to choose either a replacement or a refund.",
                    "response_email": "Hello! Thank you for contacting us about your negative experience with our leggings. We are sorry to hear that the fabric was so thin that you could see your panties. We are also sorry to hear that they formed dots after just a few washes. We would like to offer you a refund or replacement for your purchase. You can reach us by phone at 1-800-555-1212 or by email at [email protected] Thank you for your understanding."
                }}
                """
    model_version = "gemini-1.0-pro-vision"

    if review_image is None:
        prompt = [context, None, inventory_image]
        embed_inputs = [context, None, inventory_image_uri]
    else:
        prompt = [context, review_image, inventory_image]
        embed_inputs = [context, review_image_uri, inventory_image_uri]

    prompt_embeddings = get_embeddings(embed_inputs)
    review_embeddings = get_text_embeddings(review_text)
    publish_prompt_pubsub(
        review_embeddings,
        context,
        prompt_embeddings[0],
        prompt_embeddings[1],
        model_version,
        policy_version)

    output = get_response(model_version, prompt)

    output_dict = output.to_dict()
    safety_ratings = output_dict["candidates"][0]["safety_ratings"]
    response = output.text
    response_dict = json_repair.loads(response)
    response_embed = get_text_embeddings(response)
    publish_response_pubsub(
        response,
        safety_ratings,
        response_embed)
    return response_dict
