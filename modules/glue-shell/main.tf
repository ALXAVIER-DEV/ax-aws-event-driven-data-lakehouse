resource "aws_s3_object" "script" {
  bucket = var.bucket_name
  key    = var.script_s3_key
  source = var.script_path
  etag   = filemd5(var.script_path)
}

resource "aws_glue_job" "this" {
  name     = var.job_name
  role_arn = var.role_arn

  command {
    name            = "pythonshell"
    python_version  = "3.9"
    script_location = "s3://${var.bucket_name}/${aws_s3_object.script.key}"
  }

  default_arguments = {
    "--job-language"          = "python"
    "--bucket_name"           = var.bucket_name
    "--database_name"         = var.database_name
    "--raw_table_name"        = var.raw_table_name
    "--curated_table_name"    = var.curated_table_name
    "--athena_workgroup_name" = var.athena_workgroup_name
    "--athena_results_prefix" = var.athena_results_prefix
    "--raw_prefix"            = var.raw_prefix
    "--curated_prefix"        = var.curated_prefix
    "--enable-metrics"        = var.enable_metrics ? "true" : "false"
  }

  execution_property {
    max_concurrent_runs = 1
  }

  max_capacity = 0.0625
  tags         = var.tags
}

resource "aws_glue_trigger" "scheduled" {
  count = var.enable_schedule ? 1 : 0

  name              = var.trigger_name
  type              = "SCHEDULED"
  schedule          = var.schedule_expression
  start_on_creation = true

  actions {
    job_name = aws_glue_job.this.name
  }

  tags = var.tags
}
