-- athena/dml_load_curated_messages.sql
INSERT INTO onboarding.curated_messages_parquet
SELECT
    event_id,
    from_iso8601_timestamp(ingestion_ts),
    payload.id,
    payload.mensagem,
    payload.autor,
    date
FROM onboarding.raw_messages_json;