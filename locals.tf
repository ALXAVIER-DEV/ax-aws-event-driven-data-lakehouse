locals {
  name_prefix = "${var.project_name}-${var.environment}"

  bucket_name           = "${local.name_prefix}-datalake"
  sns_topic_name        = "${local.name_prefix}-topic"
  sqs_queue_name        = "${local.name_prefix}-queue"
  lambda_function_name  = "${local.name_prefix}-ingest"
  lambda_role_name      = "${local.name_prefix}-lambda-role"
  athena_workgroup_name = "${local.name_prefix}-athena"
  raw_prefix            = "raw/messages"

  tags = merge(var.tags, {
    Environment = var.environment
  })
}
