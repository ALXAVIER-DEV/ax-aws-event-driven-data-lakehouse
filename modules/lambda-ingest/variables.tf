variable "source_file" {
  type = string
}

variable "output_path" {
  type = string
}

variable "function_name" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "prefix_base" {
  type    = string
  default = "raw/messages"
}

variable "queue_arn" {
  type = string
}

variable "log_retention_in_days" {
  type    = number
  default = 14
}

variable "log_format" {
  type    = string
  default = "JSON"
}

variable "application_log_level" {
  type    = string
  default = "INFO"
}

variable "system_log_level" {
  type    = string
  default = "INFO"
}

variable "tags" {
  type = map(string)
}
