PROJ=${PROJ}
REGION=${REGION}
IMG_TAG="gcr.io/$PROJ/gemini-multimodal-demo"
SERVICE_ACCOUNT="gemini-demo-app@$PROJ.iam.gserviceaccount.com"

gcloud run deploy "gemini-multimodal-demo"  \
    --project "$PROJ"                \
    --image "$IMG_TAG"               \
    --update-env-vars "PROJ=$PROJ, REGION=$REGION"     \
    --platform "managed"             \
    --port 5000                      \
    --region "$REGION"               \
    --service-account "$SERVICE_ACCOUNT" \
    --allow-unauthenticated
