resource "aws_cloudwatch_log_group" "this" {
  name = "px-${var.resource_prefix}ui${var.resource_suffix}"

  retention_in_days = 30
  
  tags = var.standard_tags
}
