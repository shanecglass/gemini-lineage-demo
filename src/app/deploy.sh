# PROJ=${PROJECT_ID}
PROJ="data-quality-demo-next-24"
# REGION=${REGION}
REGION="us-central1"
# OUTPUT_BUCKET=${OUTPUT_BUCKET}
OUTPUT_BUCKET="gaacsa-0a81907e"
IMG_TAG="gcr.io/$PROJ/gemini-multimodal-demo"
SERVICE_ACCOUNT="gemini-demo-app@$PROJ.iam.gserviceaccount.com"

gcloud run deploy "gemini-multimodal-demo"  \
    --project "$PROJ"                 \
    --image "$IMG_TAG"               \
    --update-env-vars "PROJECT_ID=$PROJ, REGION=$REGION, OUTPUT_BUCKET=$OUTPUT_BUCKET"    \
    --platform "managed"             \
    --port 5000                      \
    --region "$REGION"               \
    --service-account "$SERVICE_ACCOUNT" \
    --allow-unauthenticated
