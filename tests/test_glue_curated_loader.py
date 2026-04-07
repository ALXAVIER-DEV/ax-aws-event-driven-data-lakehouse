import importlib
import sys
import types
import unittest
from unittest.mock import MagicMock, patch


class GlueCuratedLoaderTests(unittest.TestCase):
    def setUp(self) -> None:
        sys.modules.pop("glue_src.curated_loader", None)

        self.mock_athena = MagicMock()
        self.mock_s3 = MagicMock()
        fake_boto3 = types.SimpleNamespace(
            client=MagicMock(side_effect=[self.mock_athena, self.mock_s3])
        )
        self.modules_patcher = patch.dict(sys.modules, {"boto3": fake_boto3})
        self.modules_patcher.start()

        self.module = importlib.import_module("glue_src.curated_loader")

    def tearDown(self) -> None:
        self.modules_patcher.stop()
        sys.modules.pop("glue_src.curated_loader", None)

    def test_parse_args_supports_local_execution_without_awsglue(self) -> None:
        with patch.object(self.module, "getResolvedOptions", None):
            args = self.module.parse_args(
                [
                    "curated_loader.py",
                    "--bucket_name",
                    "bucket",
                    "--database_name",
                    "onboarding",
                    "--raw_table_name",
                    "raw_messages_json",
                    "--curated_table_name",
                    "curated_messages_parquet",
                    "--athena_workgroup_name",
                    "wg",
                    "--athena_results_prefix",
                    "athena-results",
                    "--raw_prefix",
                    "raw/messages",
                    "--curated_prefix",
                    "curated/messages",
                ]
            )

        self.assertEqual(args["bucket_name"], "bucket")
        self.assertEqual(args["curated_prefix"], "curated/messages")

    def test_refresh_curated_partition_uses_valid_drop_partition_statement(self) -> None:
        executed_sql: list[str] = []

        def record_sql(sql: str, **_: str) -> str:
            executed_sql.append(sql)
            return "query-id"

        with patch.object(self.module, "run_query", side_effect=record_sql), patch.object(
            self.module, "delete_prefix"
        ) as delete_prefix:
            self.module.refresh_curated_partition(
                bucket_name="bucket",
                database_name="onboarding",
                curated_table_name="curated_messages_parquet",
                curated_prefix="curated/messages",
                raw_table_name="raw_messages_json",
                partition_date="20260407",
                athena_workgroup_name="wg",
                athena_results_prefix="athena-results",
            )

        delete_prefix.assert_called_once_with("bucket", "curated/messages/date=20260407/")
        self.assertEqual(len(executed_sql), 2)
        self.assertIn(
            "ALTER TABLE onboarding.curated_messages_parquet DROP PARTITION IF EXISTS (date='20260407')",
            executed_sql[0],
        )
        self.assertIn("INSERT INTO onboarding.curated_messages_parquet", executed_sql[1])


if __name__ == "__main__":
    unittest.main()
