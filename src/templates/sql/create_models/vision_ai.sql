CREATE OR REPLACE MODEL
`${project_id}.${dataset_id}.vision_ai`
REMOTE WITH CONNECTION `${project_id}.${region}.${connection_id}`
OPTIONS (REMOTE_SERVICE_TYPE = 'CLOUD_AI_VISION_V1');
