import sys
import time

import boto3
from awsglue.utils import getResolvedOptions


args = getResolvedOptions(
    sys.argv,
    [
        "bucket_name",
        "database_name",
        "raw_table_name",
        "curated_table_name",
        "athena_workgroup_name",
        "athena_results_prefix",
        "raw_prefix",
        "curated_prefix",
    ],
)

athena = boto3.client("athena")
s3 = boto3.client("s3")

BUCKET_NAME = args["bucket_name"]
DATABASE_NAME = args["database_name"]
RAW_TABLE_NAME = args["raw_table_name"]
CURATED_TABLE_NAME = args["curated_table_name"]
ATHENA_WORKGROUP_NAME = args["athena_workgroup_name"]
ATHENA_RESULTS_PREFIX = args["athena_results_prefix"]
RAW_PREFIX = args["raw_prefix"].rstrip("/")
CURATED_PREFIX = args["curated_prefix"].rstrip("/")


def athena_output_location() -> str:
    return f"s3://{BUCKET_NAME}/{ATHENA_RESULTS_PREFIX}/"


def run_query(sql: str) -> str:
    response = athena.start_query_execution(
        QueryString=sql,
        WorkGroup=ATHENA_WORKGROUP_NAME,
        QueryExecutionContext={"Database": DATABASE_NAME},
        ResultConfiguration={"OutputLocation": athena_output_location()},
    )
    query_execution_id = response["QueryExecutionId"]

    while True:
        execution = athena.get_query_execution(QueryExecutionId=query_execution_id)
        status = execution["QueryExecution"]["Status"]["State"]
        if status in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(3)

    if status != "SUCCEEDED":
        reason = execution["QueryExecution"]["Status"].get("StateChangeReason", "Unknown failure")
        raise RuntimeError(f"Athena query failed with status {status}: {reason}")

    return query_execution_id


def fetch_text_rows(query_execution_id: str) -> list[str]:
    paginator = athena.get_paginator("get_query_results")
    rows = []

    for page in paginator.paginate(QueryExecutionId=query_execution_id):
        for row in page["ResultSet"]["Rows"]:
            values = [item.get("VarCharValue", "") for item in row["Data"]]
            if values:
                rows.append(values[0])

    return rows


def delete_prefix(bucket_name: str, prefix: str) -> None:
    paginator = s3.get_paginator("list_objects_v2")

    for page in paginator.paginate(Bucket=bucket_name, Prefix=prefix):
        objects = [{"Key": item["Key"]} for item in page.get("Contents", [])]
        if not objects:
            continue
        s3.delete_objects(Bucket=bucket_name, Delete={"Objects": objects})


def create_database() -> None:
    run_query(f"CREATE DATABASE IF NOT EXISTS {DATABASE_NAME}")


def create_raw_table() -> None:
    sql = f"""
    CREATE EXTERNAL TABLE IF NOT EXISTS {DATABASE_NAME}.{RAW_TABLE_NAME} (
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
    LOCATION 's3://{BUCKET_NAME}/{RAW_PREFIX}/'
    """
    run_query(sql)


def repair_raw_table() -> None:
    run_query(f"MSCK REPAIR TABLE {DATABASE_NAME}.{RAW_TABLE_NAME}")


def create_curated_table() -> None:
    sql = f"""
    CREATE EXTERNAL TABLE IF NOT EXISTS {DATABASE_NAME}.{CURATED_TABLE_NAME} (
      event_id string,
      ingestion_ts timestamp,
      id string,
      mensagem string,
      autor string
    )
    PARTITIONED BY (date string)
    STORED AS PARQUET
    LOCATION 's3://{BUCKET_NAME}/{CURATED_PREFIX}/'
    """
    run_query(sql)


def list_raw_partitions() -> list[str]:
    query_execution_id = run_query(f"SHOW PARTITIONS {DATABASE_NAME}.{RAW_TABLE_NAME}")
    rows = fetch_text_rows(query_execution_id)
    return [row for row in rows if row and row != "partition"]


def refresh_curated_partition(partition_date: str) -> None:
    curated_partition_prefix = f"{CURATED_PREFIX}/date={partition_date}/"
    delete_prefix(BUCKET_NAME, curated_partition_prefix)

    run_query(
        f"ALTER TABLE {DATABASE_NAME}.{CURATED_TABLE_NAME} "
        f"DROP IF EXISTS PARTITION (date='{partition_date}')"
    )

    insert_sql = f"""
    INSERT INTO {DATABASE_NAME}.{CURATED_TABLE_NAME}
    SELECT
      event_id,
      from_iso8601_timestamp(ingestion_ts),
      payload.id,
      payload.mensagem,
      payload.autor,
      date
    FROM {DATABASE_NAME}.{RAW_TABLE_NAME}
    WHERE date = '{partition_date}'
    """
    run_query(insert_sql)


def main() -> None:
    create_database()
    create_raw_table()
    repair_raw_table()
    create_curated_table()

    partitions = list_raw_partitions()
    if not partitions:
        print("No raw partitions found. Nothing to load into curated.")
        return

    for partition in partitions:
        partition_date = partition.split("=", 1)[1]
        print(f"Refreshing curated partition for date={partition_date}")
        refresh_curated_partition(partition_date)

    print("Curated load completed successfully.")


if __name__ == "__main__":
    main()
