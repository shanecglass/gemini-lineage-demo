# This file will get executed when the function is executed
import json
import os
import vertexai

from google.cloud import pubsub_v1
from vertexai.language_models import TextGenerationModel, TextEmbeddingModel

# Change the values of the 4 lines below to match your requirements

# Project ID
project_id = os.environ['PROJ']
# Pub/Sub Topic ID for prompt
prompt_pubsub_topic_id = "email_marketing_llm_prompts"
# Pub/Sub Topic ID for response
response_pubsub_topic_id = "email_marketing_llm_responses"
# GCP region
location = os.environ['REGION']

publisher = pubsub_v1.PublisherClient()
prompt_topic_path = publisher.topic_path(project_id, prompt_pubsub_topic_id)
response_topic_path = publisher.topic_path(project_id, response_pubsub_topic_id)

vertexai.init(project=project_id,
              location=location)


def get_text_embeddings(input):
    model = TextEmbeddingModel.from_pretrained("textembedding-gecko@001")
    try:
        embeddings = model.get_embeddings([input])
        output = [embedding.values for embedding in embeddings]
        return output
    except Exception:
        return [None for _ in range(len(input))]


def get_response(input_prompt):
    model = TextGenerationModel.from_pretrained("text-bison@001")
    # These parameters can be modified to better suit your needs. Check out the documentation to learn more: https://cloud.google.com/vertex-ai/docs/generative-ai/model-reference/text#request_body
    parameters = {
        # Temperature controls the degree of randomness in token selection.
        "temperature": 0.9,
        # Token limit determines the maximum amount of text output.
        "max_output_tokens": 512,
        # Tokens are selected from most probable to least until the sum of their probabilities equals the top_p value.
        "top_p": 0.8,
        # A top_k of 1 means the selected token is the most probable among all tokens.
        "top_k": 40,
    }
    output = model.predict(
        prompt=input_prompt,
        **parameters
    )
    print(output.text)
    return output


def publish_prompt_pubsub(session, prompt, text_embedding):
    text_embedding = json.dumps(text_embedding)
    dict = {"session_id": session, "prompt": prompt,
            "embedding": text_embedding}
    data_string = json.dumps(dict)
    data = data_string.encode("utf-8")
    future = publisher.publish(prompt_topic_path, data)
    return future


def publish_response_pubsub(session, response_text, safety_attributes, text_embedding):
    text_embedding = json.dumps(text_embedding)
    dict = {"session_id": session, "response": response_text,
            "safety_attributes": safety_attributes, "embedding": text_embedding}
    data_string = json.dumps(dict)
    data = data_string.encode("utf-8")
    future = publisher.publish(response_topic_path, data)
    return future
