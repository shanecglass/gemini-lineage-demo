PROJ=${PROJECT_ID}
REGION=${REGION}

gcloud builds submit --project $PROJ --tag "gcr.io/$PROJ/gemini-multimodal-demo"
