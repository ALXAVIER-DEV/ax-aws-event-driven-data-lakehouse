-- Template variables:
--   ${database_name}
--   ${curated_table_name}
--   ${bucket_name}
--   ${curated_prefix}

CREATE EXTERNAL TABLE IF NOT EXISTS ${database_name}.${curated_table_name} (
  event_id string,
  ingestion_ts timestamp,
  id string,
  mensagem string,
  autor string
)
PARTITIONED BY (date string)
STORED AS PARQUET
LOCATION 's3://${bucket_name}/${curated_prefix}/';
