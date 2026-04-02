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

variable "tags" {
  type = map(string)
}
