output "job_name" {
  value = aws_glue_job.this.name
}

output "trigger_name" {
  value = try(aws_glue_trigger.scheduled[0].name, null)
}
