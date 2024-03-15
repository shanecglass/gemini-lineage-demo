CREATE OR REPLACE MODEL
`${project_id}.${dataset_id}.generate_text`
REMOTE WITH CONNECTION `${connection_id}`
OPTIONS (ENDPOINT='gemini-pro');
