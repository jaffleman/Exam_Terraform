
resource "aws_ebs_volume" "this" {
  availability_zone = var.availability_zone
  size              = var.size_gb
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.namespace}-wp-ebs"
    Role = "wp-data"
  }
}

resource "aws_volume_attachment" "this" {
  device_name = var.device_name
  volume_id   = aws_ebs_volume.this.id
  instance_id = var.instance_id
}

