# This file will get executed when the function is executed
import json
import os
import vertexai

from google.cloud import pubsub_v1
from vertexai import generative_models
from vertexai.generative_models import GenerativeModel
from vertexai.language_models import TextEmbeddingModel
from vertexai.vision_models import Image, MultiModalEmbeddingModel


# Change the values of the 4 lines below to match your requirements

# Project ID
project_id = os.environ['PROJECT_ID']
# Pub/Sub Topic ID for prompt
prompt_pubsub_topic_id = "gemini-multimodal-demo-reviews-prompts"
# Pub/Sub Topic ID for response
response_pubsub_topic_id = "gemini-multimodal-demo-reviews-responses"
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
        "textembedding-gecko-multilingual@001")
    text_embeddings = text_embed_model.get_embeddings([text_input])
    text_embed_output = [
        text_embedding.values for text_embedding in text_embeddings]
    return text_embed_output


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


def publish_prompt_pubsub(review_id,
                          review_embeddings,
                          prompt,
                          text_embed,
                          image_embed,
                          model_version,
                          policy_version):
    text_embed = json.dumps(text_embed)
    review_embeddings = json.dumps(review_embeddings)
    image_embed = json.dumps(image_embed)
    dict = {"review_id": review_id,
            "review_embedding": review_embeddings,
            "prompt": prompt,
            "prompt_embedding": text_embed,
            "image_embedding": image_embed,
            "model_version": model_version,
            "policy_version": policy_version}
    data_string = json.dumps(dict)
    data = data_string.encode("utf-8")
    future = publisher.publish(prompt_topic_path, data)
    print(f"Published prompt to {prompt_topic_path} for {review_id}")
    return (future)


def publish_response_pubsub(review_id, response_text,
                            safety_attributes, embedding):
    embedding = json.dumps(embedding)
    dict = {"review_id": review_id,
            "response": response_text,
            "safety_attributes": safety_attributes,
            "response_embedding": embedding}
    data_string = json.dumps(dict)
    data = data_string.encode("utf-8")
    future = publisher.publish(response_topic_path, data)
    print(f"Published response to {response_topic_path} for {review_id}")
    return (future)
