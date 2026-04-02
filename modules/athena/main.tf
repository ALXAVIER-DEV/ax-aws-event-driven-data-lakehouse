resource "aws_athena_workgroup" "this" {
  name = var.workgroup_name

  configuration {
    result_configuration {
      output_location = "s3://${var.bucket_name}/athena-results/"
    }
  }

  tags = var.tags
}