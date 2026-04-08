import json
import boto3
import uuid
from datetime import datetime, timezone
import os

s3 = boto3.client("s3")

BUCKET_NAME = os.environ["BUCKET_NAME"]
PREFIX_BASE = os.environ.get("PREFIX_BASE", "raw/messages")


def log_event(level, message, **fields):
    entry = {"level": level, "message": message, **fields}
    print(json.dumps(entry))


def lambda_handler(event, context):
    log_event("INFO", "Received batch.", record_count=len(event.get("Records", [])))
    batch_item_failures = []

    for record in event.get("Records", []):
        try:
            body = record.get("body", "{}")
            body_json = json.loads(body)

            if "Message" in body_json:
                message_payload = json.loads(body_json["Message"])
            else:
                message_payload = body_json

            now = datetime.now(timezone.utc)
            date_partition = now.strftime("%Y%m%d")
            ts = now.strftime("%Y%m%dT%H%M%SZ")

            output = {
                "event_id": str(uuid.uuid4()),
                "ingestion_ts": now.isoformat(),
                "payload": message_payload
            }

            key = f"{PREFIX_BASE}/date={date_partition}/msg_{ts}_{uuid.uuid4().hex}.json"

            s3.put_object(
                Bucket=BUCKET_NAME,
                Key=key,
                Body=json.dumps(output).encode("utf-8"),
                ContentType="application/json"
            )
            log_event(
                "INFO",
                "Stored ingested event in S3.",
                message_id=record.get("messageId"),
                s3_key=key,
            )
        except Exception as exc:
            log_event(
                "ERROR",
                "Failed to process record.",
                message_id=record.get("messageId"),
                error=str(exc),
            )
            batch_item_failures.append({"itemIdentifier": record["messageId"]})

    return {"batchItemFailures": batch_item_failures}
