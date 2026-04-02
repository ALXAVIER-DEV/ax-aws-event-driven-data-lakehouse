module "sns_topic" {
  source = "./modules/sns-topic"

  name = local.sns_topic_name
  tags = local.tags
}

module "sqs_queue" {
  source = "./modules/sqs-queue"

  name                       = local.sqs_queue_name
  sns_topic_arn              = module.sns_topic.topic_arn
  visibility_timeout_seconds = 60
  max_receive_count          = 5
  tags                       = local.tags
}

module "datalake_bucket" {
  source = "./modules/s3-datalake"

  bucket_name = local.bucket_name
  tags        = local.tags
}

module "lambda_role" {
  source = "./modules/iam-lambda-role"

  role_name  = local.lambda_role_name
  bucket_arn = module.datalake_bucket.bucket_arn
  queue_arn  = module.sqs_queue.queue_arn
  tags       = local.tags
}

module "lambda_ingest" {
  source = "./modules/lambda-ingest"

  source_file   = "${path.root}/lambda_src/app.py"
  output_path   = "${path.root}/lambda_src/app.zip"
  function_name = local.lambda_function_name
  role_arn      = module.lambda_role.role_arn
  bucket_name   = module.datalake_bucket.bucket_name
  prefix_base   = local.raw_prefix
  queue_arn     = module.sqs_queue.queue_arn
  tags          = local.tags
}

module "athena" {
  source = "./modules/athena"

  workgroup_name = local.athena_workgroup_name
  bucket_name    = module.datalake_bucket.bucket_name
  tags           = local.tags
}

module "glue_role" {
  source = "./modules/iam-glue-role"

  role_name  = local.glue_role_name
  bucket_arn = module.datalake_bucket.bucket_arn
  tags       = local.tags
}

module "glue_curated_loader" {
  source = "./modules/glue-shell"

  job_name              = local.glue_job_name
  trigger_name          = local.glue_trigger_name
  role_arn              = module.glue_role.role_arn
  bucket_name           = module.datalake_bucket.bucket_name
  database_name         = local.database_name
  raw_table_name        = local.raw_table_name
  curated_table_name    = local.curated_table_name
  athena_workgroup_name = module.athena.workgroup_name
  athena_results_prefix = local.athena_results_prefix
  raw_prefix            = local.raw_prefix
  curated_prefix        = local.curated_prefix
  script_path           = "${path.root}/glue_src/curated_loader.py"
  script_s3_key         = local.glue_script_s3_key
  enable_schedule       = var.enable_curated_schedule
  schedule_expression   = var.curated_schedule_expression
  tags                  = local.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-lambda-errors"
  alarm_description   = "Alarm when Lambda ingestion reports errors."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.lambda_ingest.function_name
  }

  alarm_actions = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]
  ok_actions    = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "queue_visible_messages" {
  alarm_name          = "${local.name_prefix}-queue-visible-messages"
  alarm_description   = "Alarm when the main queue accumulates visible messages."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = module.sqs_queue.queue_name
  }

  alarm_actions = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]
  ok_actions    = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "dlq_visible_messages" {
  alarm_name          = "${local.name_prefix}-dlq-visible-messages"
  alarm_description   = "Alarm when messages reach the dead-letter queue."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = module.sqs_queue.dlq_name
  }

  alarm_actions = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]
  ok_actions    = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "glue_failed_tasks" {
  alarm_name          = "${local.name_prefix}-glue-failed-tasks"
  alarm_description   = "Alarm when the curated Glue job reports failed tasks."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "Glue"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    JobName = module.glue_curated_loader.job_name
  }

  alarm_actions = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]
  ok_actions    = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]

  tags = local.tags
}
