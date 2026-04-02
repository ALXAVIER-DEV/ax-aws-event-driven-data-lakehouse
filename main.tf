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
