-- athena/ddl_raw_messages.sql
CREATE TABLE IF NOT EXISTS onboarding.raw_messages_json (
  event_id string,
  ingestion_ts string,
  payload struct<
    id:string,
    mensagem:string,
    autor:string
  >
)
PARTITIONED BY (date string)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://BUCKET_NAME/raw/messages/';
