import functions_framework
import json
import json_repair
import modules
import pandas_gbq
import os

from vertexai.generative_models import Part


@functions_framework.http
def parse_input(request):
    request_json = request.get_json()
    calls = request_json['calls']
    for call in calls:
        review_id = str(call[0])
    return review_id


def get_required_inputs(review_id):
    # bq_client = bigquery.Client()
    project_id = os.environ['PROJECT_ID']
    regexp_inventory_uri = "r'^gs.*([0-9]{3}).png$'"
    sql = f"""
        with hold AS(
        SELECT review_text, review_language, reviews.uri AS review_image_uri, product_id, inventory.uri AS inventory_image_uri
        FROM `cymbal_sports.cleaned_reviews` reviews
        JOIN `cymbal_sports.inventory_images` inventory ON reviews.product_id = REGEXP_EXTRACT(inventory.uri, {regexp_inventory_uri})
        WHERE reviews.review_id = "{review_id}"
        ),

        policy_version AS(
        SELECT MAX(version_number) AS latest
        FROM `cymbal_sports.complete_service_policy`
        )

        SELECT hold.*, service_policy_text, policy_version.latest AS policy_version
        FROM hold, `cymbal_sports.complete_service_policy` service_policy, policy_version
        WHERE service_policy.version_number = policy_version.latest
        """
    variables_df = pandas_gbq.read_gbq(sql, project_id=project_id)
    return variables_df


def call_llm(inputs,
             review_id):
    language = inputs["review_language"][0]
    policy = inputs["service_policy_text"][0]
    review_text = inputs["review_text"][0]
    inventory_image_uri = str(inputs["inventory_image_uri"][0])
    if inputs["review_image_uri"][0] is None:
        review_image_uri = None
    else:
        review_image_uri = str(inputs["review_image_uri"][0])
    policy_version = inputs["policy_version"][0]

    if inventory_image_uri is None:
        inventory_image = None
    else:
        inventory_image = Part.from_uri(
            inventory_image_uri, mime_type="image/jpeg")

    if review_image_uri is None:
        review_image = None
    else:
        review_image = Part.from_uri(
            review_image_uri, mime_type="image/jpeg")

    context = f"""
                Provide the following response in a JSON format.
                You are an expert customer service agent for an eCommerce sporting goods retailer named Cymbal Sports.
                You receive information that a customer has had a negative experience with a product.
                Consider the review and review image to understand the customer's experience.
                The review is: {review_text}
                If it is available, The inventory image for the product they purchased is inventory_image.
                If it is available, the review image is review_image.
                The customer service policy is: {policy}
                After considering this information, use the customer service policy to determine a resolution for the customer's negative experience.
                Explain exactly what the problem is and the issue resolution.

                Then, write an email written in the language of the review to the user explaining how you are going to resolve their issue.
                The language of the review is "{language}".

                If language of the review is English, respond with the email written in the language of the review.
                If the language of the review is not English, translate the email written in the language of the review into English.

                The parent fields are issue_resolution, response_user_language, and response_translated.
                Parent fields should be lower cased.
                There are no child fields.
                Do not include JSON decorator.

                This is an example of an output that is correctly formatted:
                {{
                    "issue_resolution": "This item did not meet our quality standards. Offer the customer the option to choose either a replacement or a refund.",
                    "response_user_language": "Olá! Obrigado por nos contatar sobre sua experiência negativa com nossas leggings. Lamentamos saber que o tecido era tão fino que você podia ver sua calcinha. Também lamentamos saber que formaram pontos após apenas algumas lavagens. Gostaríamos de oferecer-lhe um reembolso ou substituição pela sua compra. Você pode entrar em contato conosco pelo telefone 1-800-555-1212 ou por e-mail em [email protegido] Obrigado pela sua compreensão",
                    "response_translated": "Hello! Thank you for contacting us about your negative experience with our leggings. We are sorry to hear that the fabric was so thin that you could see your panties. We are also sorry to hear that they formed dots after just a few washes. We would like to offer you a refund or replacement for your purchase. You can reach us by phone at 1-800-555-1212 or by email at [email protected] Thank you for your understanding."
                }}
                """
    model_version = "gemini-1.0-pro-vision"

    if review_image is None:
        prompt = [context, None, inventory_image]
        embed_inputs = [context, None, inventory_image_uri]
    else:
        prompt = [context, review_image, inventory_image]
        embed_inputs = [context, review_image_uri, inventory_image_uri]

    prompt_embeddings = modules.get_embeddings(embed_inputs)
    review_embeddings = modules.get_text_embeddings(review_text)
    modules.publish_prompt_pubsub(
        review_id,
        review_embeddings,
        context,
        prompt_embeddings[0],
        prompt_embeddings[1],
        model_version,
        policy_version)

    output = modules.get_response(model_version, prompt)

    output_dict = output.to_dict()
    safety_ratings = output_dict["candidates"][0]["safety_ratings"]
    response = output.text
    response_dict = json_repair.loads(response)
    response_embed = modules.get_text_embeddings(response)
    modules.publish_response_pubsub(
        review_id, response,
        safety_ratings, response_embed)
    return response_dict


def run_it(request):
    try:
        return_values = []
        review_id_value = parse_input(request)
        model_inputs = get_required_inputs(review_id_value)
        model_response = call_llm(model_inputs,
                                  review_id_value)
        return_values.append(model_response)
        return_json = json.dumps(
            {"replies": [json.dumps(value) for value in return_values]})
        return return_json
    except Exception as e:
        return json.dumps({"errorMessage": str(e)}), 400
