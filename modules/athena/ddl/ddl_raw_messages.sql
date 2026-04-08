-- Template variables:
--   ${database_name}
--   ${raw_table_name}
--   ${bucket_name}
--   ${raw_prefix}

CREATE EXTERNAL TABLE IF NOT EXISTS ${database_name}.${raw_table_name} (
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
LOCATION 's3://${bucket_name}/${raw_prefix}/';
