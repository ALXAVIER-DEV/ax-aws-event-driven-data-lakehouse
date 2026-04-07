import importlib
import json
import os
import sys
import types
import unittest
from unittest.mock import MagicMock, patch


class LambdaIngestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.env_patcher = patch.dict(
            os.environ,
            {
                "BUCKET_NAME": "test-bucket",
                "PREFIX_BASE": "raw/messages",
            },
            clear=False,
        )
        self.env_patcher.start()
        sys.modules.pop("lambda_src.app", None)

        self.mock_s3 = MagicMock()
        fake_boto3 = types.SimpleNamespace(client=MagicMock(return_value=self.mock_s3))
        self.modules_patcher = patch.dict(sys.modules, {"boto3": fake_boto3})
        self.modules_patcher.start()

        self.module = importlib.import_module("lambda_src.app")

    def tearDown(self) -> None:
        self.modules_patcher.stop()
        self.env_patcher.stop()
        sys.modules.pop("lambda_src.app", None)

    def test_writes_sns_wrapped_payload_to_s3(self) -> None:
        event = {
            "Records": [
                {
                    "messageId": "msg-1",
                    "body": json.dumps(
                        {
                            "Type": "Notification",
                            "Message": json.dumps(
                                {"id": "123", "mensagem": "hello", "autor": "alice"}
                            ),
                        }
                    ),
                }
            ]
        }

        response = self.module.lambda_handler(event, None)

        self.assertEqual(response, {"batchItemFailures": []})
        self.mock_s3.put_object.assert_called_once()
        put_kwargs = self.mock_s3.put_object.call_args.kwargs
        self.assertEqual(put_kwargs["Bucket"], "test-bucket")
        self.assertTrue(put_kwargs["Key"].startswith("raw/messages/date="))

        stored_body = json.loads(put_kwargs["Body"].decode("utf-8"))
        self.assertEqual(stored_body["payload"]["id"], "123")
        self.assertEqual(stored_body["payload"]["mensagem"], "hello")
        self.assertEqual(stored_body["payload"]["autor"], "alice")
        self.assertIn("event_id", stored_body)
        self.assertIn("ingestion_ts", stored_body)

    def test_returns_batch_failure_for_invalid_record(self) -> None:
        event = {
            "Records": [
                {
                    "messageId": "msg-2",
                    "body": "{invalid-json",
                }
            ]
        }

        response = self.module.lambda_handler(event, None)

        self.assertEqual(response, {"batchItemFailures": [{"itemIdentifier": "msg-2"}]})
        self.mock_s3.put_object.assert_not_called()


if __name__ == "__main__":
    unittest.main()
