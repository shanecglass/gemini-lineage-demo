CREATE OR REPLACE MODEL
`${project_id}.${dataset_id}.nlp`
REMOTE WITH CONNECTION `${project_id}.${region}.${connection_id}`
OPTIONS (REMOTE_SERVICE_TYPE = 'CLOUD_AI_NATURAL_LANGUAGE_V1');
