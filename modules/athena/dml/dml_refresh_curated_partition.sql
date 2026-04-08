-- Template variables:
--   ${database_name}
--   ${raw_table_name}
--   ${curated_table_name}
--   ${partition_date}

ALTER TABLE ${database_name}.${curated_table_name}
DROP PARTITION IF EXISTS (date='${partition_date}');

INSERT INTO ${database_name}.${curated_table_name}
SELECT
    event_id,
    from_iso8601_timestamp(ingestion_ts),
    payload.id,
    payload.mensagem,
    payload.autor,
    date
FROM ${database_name}.${raw_table_name}
WHERE date = '${partition_date}';
