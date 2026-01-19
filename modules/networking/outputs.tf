
locals {
  public_subnet_ids  = [for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].id]
  private_subnet_ids = [for k in sort(keys(aws_subnet.private)) : aws_subnet.private[k].id]
  nat_gateway_ids    = [for k in sort(keys(aws_nat_gateway.nat)) : aws_nat_gateway.nat[k].id]
  private_rt_ids     = [for k in sort(keys(aws_route_table.private)) : aws_route_table.private[k].id]
}

output "vpc_id" { value = aws_vpc.main.id }
output "azs" { value = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs)) }
output "public_subnets" { value = local.public_subnet_ids }
output "private_subnets" { value = local.private_subnet_ids }
output "public_route_table_ids" { value = [aws_route_table.public.id] }
output "private_route_table_ids" { value = local.private_rt_ids }
output "igw_id" { value = aws_internet_gateway.igw.id }
output "natgw_ids" { value = local.nat_gateway_ids }

output "database_subnet_group" {
  description = "Nom du DB Subnet Group (ou null s'il n'est pas créé)"
  value       = try(aws_db_subnet_group.this[0].name, null)
}

output "database_subnet_group_name" {
  description = "Nom du DB Subnet Group créé"
  value       = try(aws_db_subnet_group.this[0].name, null)
}

output "web_sg_id" { value = aws_security_group.web.id }
output "admin_ssh_sg_id" { value = aws_security_group.admin_ssh.id }
