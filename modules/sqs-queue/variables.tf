variable "name" {
  type = string
}

variable "sns_topic_arn" {
  type = string
}

variable "visibility_timeout_seconds" {
  type    = number
  default = 60
}

variable "max_receive_count" {
  type    = number
  default = 5
}

variable "tags" {
  type = map(string)
}
