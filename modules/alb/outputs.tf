
output "alb_dns_name" {
  description = "Nom DNS public de l'ALB (à CNAME depuis OVH)"
  value       = aws_lb.this.dns_name
}

output "tg_arn" {
  value = aws_lb_target_group.this.arn
}
