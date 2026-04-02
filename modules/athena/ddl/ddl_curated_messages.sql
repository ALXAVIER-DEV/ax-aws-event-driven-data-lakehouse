CREATE EXTERNAL TABLE IF NOT EXISTS onboarding.curated_messages_parquet (
  event_id string,
  ingestion_ts timestamp,
  id string,
  mensagem string,
  autor string
)
PARTITIONED BY (date string)
STORED AS PARQUET
LOCATION 's3://BUCKET_NAME/curated/messages/';
