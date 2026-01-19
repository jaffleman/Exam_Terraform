
# AMI Amazon Linux 2 (x86_64, HVM, EBS gp2/gp3)
data "aws_ami" "exam-Terraform-ec2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2", "amzn2-ami-hvm-*-x86_64-gp3"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.amazon_linux2.id
  instance_type               = "t3.micro"
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  key_name                    = var.key_name

  vpc_security_group_ids = var.sg_ids
  user_data              = var.user_data

  tags = {
    Name = "${var.namespace}-ec2-wordpress"
    Role = "web"
  }
}

