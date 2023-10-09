resource "aws_security_group" "fargate_security_group" {
  name        = local.ui_backend_security_group_name
  description = "Security Group for Fargate which runs the UI Backend."
  vpc_id      = var.metaflow_vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    security_groups = [aws_security_group.ui_lb_security_group.id]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = true
    description = "Internal communication"
  }

  # egress to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all external communication"
  }

  tags = merge(
    var.standard_tags,
    {
      Metaflow = "true"
    }
  )
}

resource "aws_security_group" "ui_lb_security_group" {
  name        = local.alb_security_group_name
  description = "Security Group for ALB"
  vpc_id      = var.metaflow_vpc_id

  ingress {
    from_port   = var.certificate_arn != null ? 443 : 80
    to_port     = var.certificate_arn != null ? 443 : 80
    protocol    = "tcp"
    cidr_blocks = var.ui_allow_list
    description = var.certificate_arn != null ? "Allow public HTTPS" : "Allow public HTTP"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = true
    description = "Internal communication"
  }

  # egress to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all external communication"
  }

  tags = merge(
    var.standard_tags,
    {
      Metaflow = "true"
    }
  )
}

resource "aws_lb" "this" {
  name               = "${var.resource_prefix}alb${var.resource_suffix}"
  internal           = var.alb_internal
  load_balancer_type = "application"
  subnets            = [var.subnet1_id, var.subnet2_id]
  security_groups = [
    aws_security_group.ui_lb_security_group.id
  ]

  tags = var.standard_tags
}

resource "aws_lb_target_group" "ui_backend" {
  name        = length("${var.resource_prefix}ui-backend${var.resource_suffix}") <= 32 ? "${var.resource_prefix}ui-backend${var.resource_suffix}" : null
  port        = 8083
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.metaflow_vpc_id

  health_check {
    protocol            = "HTTP"
    port                = 8083
    path                = "/api/ping"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(var.standard_tags, {
    Name = "${var.resource_prefix}ui-backend${var.resource_suffix}"
  })
}


resource "aws_lb_target_group" "ui_static" {
  name        = length("${var.resource_prefix}ui-static${var.resource_suffix}") <= 32 ? "${var.resource_prefix}ui-static${var.resource_suffix}" : null
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.metaflow_vpc_id

  tags = merge(var.standard_tags, {
    Name = "${var.resource_prefix}ui-static${var.resource_suffix}"
  })
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.certificate_arn != null ? "443" : "80"
  protocol          = var.certificate_arn != null ? "HTTPS" : "HTTP"

  certificate_arn = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui_static.id
    order            = 100
  }

  tags = var.standard_tags
}

resource "aws_lb_listener_rule" "ui_backend" {
  listener_arn = aws_lb_listener.this.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui_backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  tags = var.standard_tags
}