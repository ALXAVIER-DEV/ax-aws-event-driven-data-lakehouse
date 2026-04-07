import sys
import time
from typing import Sequence

import boto3

try:
    from awsglue.utils import getResolvedOptions
except ImportError:  # pragma: no cover - exercised in local/unit-test execution.
    getResolvedOptions = None


ARGUMENT_NAMES = [
    "bucket_name",
    "database_name",
    "raw_table_name",
    "curated_table_name",
    "athena_workgroup_name",
    "athena_results_prefix",
    "raw_prefix",
    "curated_prefix",
]

athena = boto3.client("athena")
s3 = boto3.client("s3")


def parse_args(argv: Sequence[str]) -> dict[str, str]:
    if getResolvedOptions is not None:
        return getResolvedOptions(list(argv), ARGUMENT_NAMES)

    parsed_args: dict[str, str] = {}
    iterator = iter(argv[1:])

    for token in iterator:
        if not token.startswith("--"):
            continue

        argument_name = token[2:]
        if argument_name not in ARGUMENT_NAMES:
            continue

        try:
            parsed_args[argument_name] = next(iterator)
        except StopIteration as exc:
            raise ValueError(f"Missing value for argument --{argument_name}") from exc

    missing_arguments = [name for name in ARGUMENT_NAMES if name not in parsed_args]
    if missing_arguments:
        missing = ", ".join(f"--{name}" for name in missing_arguments)
        raise ValueError(f"Missing required arguments: {missing}")

    return parsed_args


def athena_output_location(bucket_name: str, athena_results_prefix: str) -> str:
    return f"s3://{bucket_name}/{athena_results_prefix.rstrip('/')}/"


def run_query(
    sql: str,
    *,
    bucket_name: str,
    database_name: str,
    athena_workgroup_name: str,
    athena_results_prefix: str,
) -> str:
    response = athena.start_query_execution(
        QueryString=sql,
        WorkGroup=athena_workgroup_name,
        QueryExecutionContext={"Database": database_name},
        ResultConfiguration={
            "OutputLocation": athena_output_location(bucket_name, athena_results_prefix)
        },
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
    rows: list[str] = []

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


def create_database(*, bucket_name: str, database_name: str, athena_workgroup_name: str, athena_results_prefix: str) -> None:
    run_query(
        f"CREATE DATABASE IF NOT EXISTS {database_name}",
        bucket_name=bucket_name,
        database_name=database_name,
        athena_workgroup_name=athena_workgroup_name,
        athena_results_prefix=athena_results_prefix,
    )


def create_raw_table(
    *,
    bucket_name: str,
    database_name: str,
    raw_table_name: str,
    raw_prefix: str,
    athena_workgroup_name: str,
    athena_results_prefix: str,
) -> None:
    sql = f"""
    CREATE EXTERNAL TABLE IF NOT EXISTS {database_name}.{raw_table_name} (
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
    LOCATION 's3://{bucket_name}/{raw_prefix.rstrip('/')}/'
    """
    run_query(
        sql,
        bucket_name=bucket_name,
        database_name=database_name,
        athena_workgroup_name=athena_workgroup_name,
        athena_results_prefix=athena_results_prefix,
    )


def repair_raw_table(
    *, bucket_name: str, database_name: str, raw_table_name: str, athena_workgroup_name: str, athena_results_prefix: str
) -> None:
    run_query(
        f"MSCK REPAIR TABLE {database_name}.{raw_table_name}",
        bucket_name=bucket_name,
        database_name=database_name,
        athena_workgroup_name=athena_workgroup_name,
        athena_results_prefix=athena_results_prefix,
    )


def create_curated_table(
    *,
    bucket_name: str,
    database_name: str,
    curated_table_name: str,
    curated_prefix: str,
    athena_workgroup_name: str,
    athena_results_prefix: str,
) -> None:
    sql = f"""
    CREATE EXTERNAL TABLE IF NOT EXISTS {database_name}.{curated_table_name} (
      event_id string,
      ingestion_ts timestamp,
      id string,
      mensagem string,
      autor string
    )
    PARTITIONED BY (date string)
    STORED AS PARQUET
    LOCATION 's3://{bucket_name}/{curated_prefix.rstrip('/')}/'
    """
    run_query(
        sql,
        bucket_name=bucket_name,
        database_name=database_name,
        athena_workgroup_name=athena_workgroup_name,
        athena_results_prefix=athena_results_prefix,
    )


def list_raw_partitions(
    *, bucket_name: str, database_name: str, raw_table_name: str, athena_workgroup_name: str, athena_results_prefix: str
) -> list[str]:
    query_execution_id = run_query(
        f"SHOW PARTITIONS {database_name}.{raw_table_name}",
        bucket_name=bucket_name,
        database_name=database_name,
        athena_workgroup_name=athena_workgroup_name,
        athena_results_prefix=athena_results_prefix,
    )
    rows = fetch_text_rows(query_execution_id)
    return [row for row in rows if row and row != "partition"]


def refresh_curated_partition(
    *,
    bucket_name: str,
    database_name: str,
    curated_table_name: str,
    curated_prefix: str,
    raw_table_name: str,
    partition_date: str,
    athena_workgroup_name: str,
    athena_results_prefix: str,
) -> None:
    curated_partition_prefix = f"{curated_prefix.rstrip('/')}/date={partition_date}/"
    delete_prefix(bucket_name, curated_partition_prefix)

    run_query(
        f"ALTER TABLE {database_name}.{curated_table_name} "
        f"DROP PARTITION IF EXISTS (date='{partition_date}')",
        bucket_name=bucket_name,
        database_name=database_name,
        athena_workgroup_name=athena_workgroup_name,
        athena_results_prefix=athena_results_prefix,
    )

    insert_sql = f"""
    INSERT INTO {database_name}.{curated_table_name}
    SELECT
      event_id,
      from_iso8601_timestamp(ingestion_ts),
      payload.id,
      payload.mensagem,
      payload.autor,
      date
    FROM {database_name}.{raw_table_name}
    WHERE date = '{partition_date}'
    """
    run_query(
        insert_sql,
        bucket_name=bucket_name,
        database_name=database_name,
        athena_workgroup_name=athena_workgroup_name,
        athena_results_prefix=athena_results_prefix,
    )


def main(argv: Sequence[str] | None = None) -> None:
    resolved_argv = list(argv or sys.argv)
    args = parse_args(resolved_argv)

    create_database(
        bucket_name=args["bucket_name"],
        database_name=args["database_name"],
        athena_workgroup_name=args["athena_workgroup_name"],
        athena_results_prefix=args["athena_results_prefix"],
    )
    create_raw_table(
        bucket_name=args["bucket_name"],
        database_name=args["database_name"],
        raw_table_name=args["raw_table_name"],
        raw_prefix=args["raw_prefix"],
        athena_workgroup_name=args["athena_workgroup_name"],
        athena_results_prefix=args["athena_results_prefix"],
    )
    repair_raw_table(
        bucket_name=args["bucket_name"],
        database_name=args["database_name"],
        raw_table_name=args["raw_table_name"],
        athena_workgroup_name=args["athena_workgroup_name"],
        athena_results_prefix=args["athena_results_prefix"],
    )
    create_curated_table(
        bucket_name=args["bucket_name"],
        database_name=args["database_name"],
        curated_table_name=args["curated_table_name"],
        curated_prefix=args["curated_prefix"],
        athena_workgroup_name=args["athena_workgroup_name"],
        athena_results_prefix=args["athena_results_prefix"],
    )

    partitions = list_raw_partitions(
        bucket_name=args["bucket_name"],
        database_name=args["database_name"],
        raw_table_name=args["raw_table_name"],
        athena_workgroup_name=args["athena_workgroup_name"],
        athena_results_prefix=args["athena_results_prefix"],
    )
    if not partitions:
        print("No raw partitions found. Nothing to load into curated.")
        return

    for partition in partitions:
        partition_date = partition.split("=", 1)[1]
        print(f"Refreshing curated partition for date={partition_date}")
        refresh_curated_partition(
            bucket_name=args["bucket_name"],
            database_name=args["database_name"],
            curated_table_name=args["curated_table_name"],
            curated_prefix=args["curated_prefix"],
            raw_table_name=args["raw_table_name"],
            partition_date=partition_date,
            athena_workgroup_name=args["athena_workgroup_name"],
            athena_results_prefix=args["athena_results_prefix"],
        )

    print("Curated load completed successfully.")


if __name__ == "__main__":
    main()
