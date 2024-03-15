PROJECT_ID=${PROJECT_ID}
REGION=${REGION}
IMG_TAG="gcr.io/$PROJECT_ID/gemini-multimodal-demo"
SERVICE_ACCOUNT="gemini-demo-app@$PROJECT_ID.iam.gserviceaccount.com"

gcloud run deploy "gemini-multimodal-demo"  \
    --project "$PROJECT_ID"                \
    --image "$IMG_TAG"               \
    --update-env-vars "PROJECT_ID=$PROJECT_ID, REGION=$REGION"     \
    --platform "managed"             \
    --port 5000                      \
    --region "$REGION"               \
    --service-account "$SERVICE_ACCOUNT" \
    --allow-unauthenticated
