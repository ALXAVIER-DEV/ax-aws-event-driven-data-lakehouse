output "sns_topic_arn" {
  value = module.sns_topic.topic_arn
}

output "sqs_queue_arn" {
  value = module.sqs_queue.queue_arn
}

output "sqs_dlq_arn" {
  value = module.sqs_queue.dlq_arn
}

output "datalake_bucket_name" {
  value = module.datalake_bucket.bucket_name
}

output "lambda_function_name" {
  value = module.lambda_ingest.function_name
}

output "lambda_log_group_name" {
  value = module.lambda_ingest.log_group_name
}

output "athena_workgroup_name" {
  value = module.athena.workgroup_name
}

output "glue_curated_job_name" {
  value = module.glue_curated_loader.job_name
}

output "glue_curated_trigger_name" {
  value = module.glue_curated_loader.trigger_name
}

output "operations_dashboard_name" {
  value = aws_cloudwatch_dashboard.operations.dashboard_name
}

output "target_account_id" {
  value = local.target_account_id
}
