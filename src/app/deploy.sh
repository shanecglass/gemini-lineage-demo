PROJ=${PROJ}
REGION=${REGION}
IMG_TAG="gcr.io/$PROJ/email-marketing-llm"
SERVICE_ACCOUNT="demo-app@$PROJ.iam.gserviceaccount.com"

gcloud run deploy "email-marketing-llm-app"  \
    --project "$PROJ"                \
    --image "$IMG_TAG"               \
    --update-env-vars "PROJ=$PROJ, REGION=$REGION"     \
    --platform "managed"             \
    --port 5000                      \
    --region "$REGION"               \
    --service-account "$SERVICE_ACCOUNT" \
    --allow-unauthenticated
