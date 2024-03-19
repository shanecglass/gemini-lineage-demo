# PROJECT_ID=${PROJECT_ID}
PROJECT_ID="next-demo-testing-3"
# REGION=${REGION}
REGION="us-central1"
# OUTPUT_BUCKET=${OUTPUT_BUCKET}
OUTPUT_BUCKET="gs://gaacsa-97913df5"

gcloud builds submit --tag "gcr.io/$PROJECT_ID/gemini-multimodal-demo"
