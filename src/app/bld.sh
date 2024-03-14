PROJ=${PROJ}
REGION=${REGION}
gcloud builds submit --tag "gcr.io/$PROJ/email-marketing-llm"
