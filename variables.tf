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

variable "cross_account_role_name" {
  type    = string
  default = "terraform-deployment-role"
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
