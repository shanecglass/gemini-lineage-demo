CREATE OR REPLACE MODEL
`${project_id}.${dataset_id}.translate`
REMOTE WITH CONNECTION `${project_id}.${region}.${connection_id}`
OPTIONS (REMOTE_SERVICE_TYPE = 'CLOUD_AI_TRANSLATE_V3');
