
output "lt_id" { value = aws_launch_template.this.id }
output "asg_arn" { value = aws_autoscaling_group.this.arn }
output "asg_name" { value = aws_autoscaling_group.this.name }
