variable "job_name" {
  type = string
}

variable "trigger_name" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "database_name" {
  type = string
}

variable "raw_table_name" {
  type = string
}

variable "curated_table_name" {
  type = string
}

variable "athena_workgroup_name" {
  type = string
}

variable "athena_results_prefix" {
  type = string
}

variable "raw_prefix" {
  type = string
}

variable "curated_prefix" {
  type = string
}

variable "script_path" {
  type = string
}

variable "script_s3_key" {
  type = string
}

variable "enable_schedule" {
  type    = bool
  default = true
}

variable "schedule_expression" {
  type    = string
  default = "cron(0/15 * * * ? *)"
}

variable "enable_metrics" {
  type    = bool
  default = true
}

variable "tags" {
  type = map(string)
}
