data "aws_caller_identity" "current" {
  lifecycle {
    postcondition {
      condition     = self.account_id == local.target_account_id
      error_message = "The active AWS credentials do not match the selected environment account."
    }
  }
}

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

  source_file           = "${path.root}/lambda_src/app.py"
  output_path           = "${path.root}/lambda_src/app.zip"
  function_name         = local.lambda_function_name
  role_arn              = module.lambda_role.role_arn
  bucket_name           = module.datalake_bucket.bucket_name
  prefix_base           = local.raw_prefix
  queue_arn             = module.sqs_queue.queue_arn
  log_retention_in_days = var.lambda_log_retention_in_days
  log_format            = "JSON"
  application_log_level = "INFO"
  system_log_level      = "INFO"
  tags                  = local.tags
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
  enable_metrics        = var.enable_glue_metrics
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

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.name_prefix}-lambda-throttles"
  alarm_description   = "Alarm when Lambda ingestion is throttled."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
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

resource "aws_cloudwatch_metric_alarm" "lambda_duration_p95" {
  alarm_name          = "${local.name_prefix}-lambda-duration-p95"
  alarm_description   = "Alarm when Lambda ingestion p95 duration is close to timeout."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p95"
  threshold           = var.lambda_duration_p95_threshold_ms
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

resource "aws_cloudwatch_metric_alarm" "queue_oldest_message_age" {
  alarm_name          = "${local.name_prefix}-queue-oldest-message-age"
  alarm_description   = "Alarm when the oldest message age in the queue indicates processing lag."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.queue_oldest_message_age_threshold_seconds
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

resource "aws_cloudwatch_event_rule" "glue_job_failures" {
  name        = "${local.name_prefix}-glue-job-failures"
  description = "Capture failures for the curated Glue job."

  event_pattern = jsonencode({
    source      = ["aws.glue"]
    detail-type = ["Glue Job State Change"]
    detail = {
      jobName = [module.glue_curated_loader.job_name]
      state   = ["FAILED", "TIMEOUT", "STOPPED"]
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "glue_job_failures_to_sns" {
  count = var.alarm_topic_arn == null ? 0 : 1

  arn  = var.alarm_topic_arn
  rule = aws_cloudwatch_event_rule.glue_job_failures.name
}

resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "${local.name_prefix}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Ingestion Health"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", module.lambda_ingest.function_name],
            [".", "Errors", ".", "."],
            [".", "Throttles", ".", "."],
            [".", "Duration", ".", ".", { stat = "p95", label = "Duration p95" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "SQS Backlog"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", module.sqs_queue.queue_name],
            [".", "ApproximateNumberOfMessagesNotVisible", ".", "."],
            [".", "ApproximateAgeOfOldestMessage", ".", ".", { stat = "Maximum", label = "Oldest Message Age" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", module.sqs_queue.dlq_name, { label = "DLQ Visible" }]
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Glue Curated Loader Logs"
          region = var.aws_region
          query  = "SOURCE '/aws-glue/python-jobs/output' | fields @timestamp, @message | filter @message like /${module.glue_curated_loader.job_name}/ or @message like /Refreshing curated partition/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Structured Logs"
          region = var.aws_region
          query  = "SOURCE '${module.lambda_ingest.log_group_name}' | fields @timestamp, level, message, error, record_count | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })
}
