# PROJ=${PROJECT_ID}
PROJ="data-quality-demo-next-24"
# REGION=${REGION}
REGION="us-central1"

gcloud builds submit --project $PROJ --tag "gcr.io/$PROJ/gemini-multimodal-demo"
