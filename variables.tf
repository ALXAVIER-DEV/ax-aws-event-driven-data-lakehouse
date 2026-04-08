variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

variable "project_name" {
  type    = string
  default = "ax-onboarding"
}

variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "hom", "prod"], var.environment)
    error_message = "environment must be one of: dev, hom, prod."
  }
}

variable "dev_account_id" {
  type = string
}

variable "hom_account_id" {
  type = string
}

variable "prod_account_id" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {
    Project    = "ax-onboarding"
    ManagedBy  = "Terraform"
    Owner      = "Ale"
    CostCenter = "Data"
  }
}

variable "alarm_topic_arn" {
  type    = string
  default = null
}

variable "enable_curated_schedule" {
  type    = bool
  default = true
}

variable "curated_schedule_expression" {
  type    = string
  default = "cron(0/15 * * * ? *)"
}

variable "enable_glue_metrics" {
  type    = bool
  default = true
}

variable "lambda_log_retention_in_days" {
  type    = number
  default = 14
}

variable "lambda_duration_p95_threshold_ms" {
  type    = number
  default = 45000
}

variable "queue_oldest_message_age_threshold_seconds" {
  type    = number
  default = 300
}
