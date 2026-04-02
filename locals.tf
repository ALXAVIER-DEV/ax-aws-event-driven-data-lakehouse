locals {
  name_prefix = "${var.project_name}-${var.environment}"

  bucket_name           = "${local.name_prefix}-datalake"
  sns_topic_name        = "${local.name_prefix}-topic"
  sqs_queue_name        = "${local.name_prefix}-queue"
  lambda_function_name  = "${local.name_prefix}-ingest"
  lambda_role_name      = "${local.name_prefix}-lambda-role"
  glue_role_name        = "${local.name_prefix}-glue-role"
  glue_job_name         = "${local.name_prefix}-curated-loader"
  glue_trigger_name     = "${local.name_prefix}-curated-schedule"
  athena_workgroup_name = "${local.name_prefix}-athena"
  raw_prefix            = "raw/messages"
  curated_prefix        = "curated/messages"
  athena_results_prefix = "athena-results"
  glue_script_s3_key    = "glue/scripts/curated_loader.py"
  database_name         = "onboarding"
  raw_table_name        = "raw_messages_json"
  curated_table_name    = "curated_messages_parquet"

  tags = merge(var.tags, {
    Environment = var.environment
  })
}
