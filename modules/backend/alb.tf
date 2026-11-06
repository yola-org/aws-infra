locals {
  has_certificate = var.acm_certificate_arn != ""
}

resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = { Name = "${var.name_prefix}-alb" }
}

resource "aws_lb_target_group" "this" {
  name        = "${var.name_prefix}-tg"
  port        = var.host_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = var.health_check_matcher
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${var.name_prefix}-tg" }
}

# HTTP: redirect to HTTPS when a certificate is configured, otherwise forward.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.has_certificate ? [] : [1]

    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }

  dynamic "default_action" {
    for_each = local.has_certificate ? [1] : []

    content {
      type = "redirect"

      redirect {
        protocol    = "HTTPS"
        port        = "443"
        status_code = "HTTP_301"
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count = local.has_certificate ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
