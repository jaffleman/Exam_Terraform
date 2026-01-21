
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Launch Template
resource "aws_launch_template" "this" {
  name_prefix   = "${var.namespace}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = var.vpc_security_group_ids

  user_data = base64encode(var.user_data)

  block_device_mappings {
    device_name = var.ebs_device_name
    ebs {
      volume_size           = var.ebs_size_gb
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.namespace}-wp"
      Role = "web"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "this" {
  name                = "${var.namespace}-asg"
  max_size            = var.max_size
  min_size            = var.min_size
  desired_capacity    = var.desired_capacity
  health_check_type   = "ELB" # s’appuie sur le TG/ALB
  vpc_zone_identifier = var.public_subnet_ids

  # Important : rattacher l’ASG au Target Group de l’ALB
  target_group_arns = [var.tg_arn]

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  # Propager tags sur instances
  tag {
    key                 = "Name"
    value               = "${var.namespace}-wp"
    propagate_at_launch = true
  }
  tag {
    key                 = "Role"
    value               = "web"
    propagate_at_launch = true
  }

  # Laisse un peu de temps aux hooks / user_data
  default_cooldown = 60

  lifecycle {
    ignore_changes = [
      desired_capacity # on laissera la politique de scaling l’ajuster
    ]
  }
}

# Politique cible (CPU) – optionnelle
resource "aws_autoscaling_policy" "cpu_target" {
  count                  = var.enable_target_tracking ? 1 : 0
  name                   = "${var.namespace}-cpu-tt"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.this.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_utilization
  }
}

