PROJ=${PROJECT_ID}
REGION=${REGION}
OUTPUT_BUCKET=${OUTPUT_BUCKET}
IMG_TAG="gcr.io/$PROJ/gemini-multimodal-demo"
SERVICE_ACCOUNT="gemini-demo-app@$PROJECT_ID.iam.gserviceaccount.com"

gcloud run deploy "gemini-multimodal-demo"  \
    --project "$PROJ"                 \
    --image "$IMG_TAG"               \
    --update-env-vars "PROJECT_ID=$PROJ, REGION=$REGION, OUTPUT_BUCKET=$OUTPUT_BUCKET"    \
    --platform "managed"             \
    --port 5000                      \
    --region "$REGION"               \
    --service-account "$SERVICE_ACCOUNT" \
    --allow-unauthenticated
