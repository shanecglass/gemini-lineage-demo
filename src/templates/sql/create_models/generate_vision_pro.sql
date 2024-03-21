CREATE OR REPLACE MODEL
`${project_id}.${dataset_id}.generate_vision_pro`
REMOTE WITH CONNECTION `${project_id}.${region}.vertex_ai_connection`
OPTIONS (ENDPOINT='gemini-pro-vision');
