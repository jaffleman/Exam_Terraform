
output "endpoint" { value = aws_db_instance.mysql.address }
output "port" { value = aws_db_instance.mysql.port }
output "db_name" { value = aws_db_instance.mysql.db_name }
output "db_username" { value = aws_db_instance.mysql.username }
output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
output "identifier" { value = aws_db_instance.mysql.id }
output "arn" { value = aws_db_instance.mysql.arn }
output "rds_sg_id" { value = aws_security_group.rds.id }
