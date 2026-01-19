
output "volume_id" { value = aws_ebs_volume.this.id }
output "attachment_device_name" { value = aws_volume_attachment.this.device_name }
