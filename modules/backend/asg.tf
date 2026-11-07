data "aws_region" "current" {}

locals {
  # Only non-secret values are embedded in the launch template. Secrets are
  # fetched at boot from Secrets Manager using var.secret_names.
  env_exports = join(" ", [
    for k, v in var.environment_variables :
    "-e ${k}=\"${replace(replace(v, "\\", "\\\\"), "\"", "\\\"")}\""
  ])
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.service_role_name
  }

  vpc_security_group_ids = [aws_security_group.asg.id]

  monitoring {
    enabled = true
  }

  user_data = base64encode(templatefile("${path.module}/templates/vestio-backend-user-data.sh.tpl", {
    aws_region   = data.aws_region.current.name
    ecr_url      = var.ecr_repository_url
    image_tag    = var.image_tag
    host_port    = var.host_port
    app_port     = var.app_port
    env_exports  = local.env_exports
    secret_names = var.secret_names
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = var.name_prefix }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = var.name_prefix }
  }
}

resource "aws_autoscaling_group" "this" {
  name                = "${var.name_prefix}-asg"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_capacity
  max_size            = var.max_capacity
  vpc_zone_identifier = aws_subnet.public[*].id

  target_group_arns         = [aws_lb_target_group.this.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = var.name_prefix
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name_prefix}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_tracking
  }
}
