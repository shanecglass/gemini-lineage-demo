# PROJECT_ID=${PROJECT_ID}
PROJECT_ID="next-demo-testing-3"
# REGION=${REGION}
REGION="us-central1"
# OUTPUT_BUCKET=${OUTPUT_BUCKET}
OUTPUT_BUCKET="gs://gaacsa-97913df5"
IMG_TAG="gcr.io/$PROJECT_ID/gemini-multimodal-demo"
SERVICE_ACCOUNT="gemini-demo-app@$PROJECT_ID.iam.gserviceaccount.com"

gcloud run deploy "gemini-multimodal-demo"  \
    --project "$PROJECT_ID"                 \
    --image "$IMG_TAG"               \
    --update-env-vars "PROJECT_ID=$PROJECT_ID, REGION=$REGION, OUTPUT_BUCKET=$OUTPUT_BUCKET"    \
    --platform "managed"             \
    --port 5000                      \
    --region "$REGION"               \
    --service-account "$SERVICE_ACCOUNT" \
    --allow-unauthenticated
