data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = var.source_file
  output_path = var.output_path
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  role             = var.role_arn
  timeout          = 60

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
      PREFIX_BASE = var.prefix_base
    }
  }

  logging_config {
    log_format            = var.log_format
    application_log_level = var.application_log_level
    system_log_level      = var.system_log_level
    log_group             = aws_cloudwatch_log_group.this.name
  }

  depends_on = [aws_cloudwatch_log_group.this]
  tags       = var.tags
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn        = var.queue_arn
  function_name           = aws_lambda_function.this.arn
  batch_size              = 1
  enabled                 = true
  function_response_types = ["ReportBatchItemFailures"]
}
