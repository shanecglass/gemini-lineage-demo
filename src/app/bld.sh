PROJ=${PROJ}
REGION=${REGION}
gcloud builds submit --tag "gcr.io/$PROJ/gemini-multimodal-demo"
