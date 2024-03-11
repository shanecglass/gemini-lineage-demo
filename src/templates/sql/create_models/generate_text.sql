CREATE OR REPLACE MODEL
`${project_id}.${dataset_id}.generate_text`
REMOTE WITH CONNECTION `${project_id}.${region}.${connection_id}`
OPTIONS (ENDPOINT='gemini-pro');
