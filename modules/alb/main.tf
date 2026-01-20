
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Security Group de l'ALB (80/443 depuis Internet)
resource "aws_security_group" "alb" {
  name        = "${var.namespace}-alb-sg"
  description = "ALB public SG (80/443 Internet)"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP (redir.)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB public
resource "aws_lb" "this" {
  name               = "${var.namespace}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

# Target Group HTTP (instances EC2)
resource "aws_lb_target_group" "this" {
  name        = "${var.namespace}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol = "HTTP"
    path     = var.health_check_path
    matcher  = "200-399"
  }
}

# Attachements des EC2 au TG

resource "aws_lb_target_group_attachment" "ec2" {
  count            = length(var.ec2_instance_ids) # <- longueur connue au plan (1)
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.ec2_instance_ids[count.index] # <- valeur connue à l’apply accepté
  port             = 80
}


# Certificat ACM (DNS validation) - eu-west-3 (via provider racine)
resource "aws_acm_certificate" "this" {
  domain_name       = var.https_fqdn
  validation_method = "DNS"

  lifecycle { create_before_destroy = true }
}

# Sortie utile : CNAME à créer chez OVH
output "acm_dns_validation_records" {
  description = "CNAME à créer (OVH) pour valider le certificat ACM"
  value = [
    for dvo in aws_acm_certificate.this.domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}

# Attend l'émission (bloque tant que les CNAME OVH ne sont pas créés)
resource "aws_acm_certificate_validation" "this" {
  certificate_arn = aws_acm_certificate.this.arn
  validation_record_fqdns = [
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.resource_record_name
  ]
}

# Listener HTTP 80 -> redirect HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Listener HTTPS 443 -> forward TG (avec cert ACM)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  depends_on = [aws_acm_certificate_validation.this]
}
