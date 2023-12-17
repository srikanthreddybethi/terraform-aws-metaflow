resource "aws_cloudwatch_log_group" "this" {
  name = "${var.resource_prefix}metadata${var.resource_suffix}"

  retention_in_days = 30
  
  tags = var.standard_tags
}
