PROJECT_ID=${PROJECT_ID}
REGION=${REGION}
gcloud builds submit --tag "gcr.io/$PROJECT_ID/gemini-multimodal-demo"
