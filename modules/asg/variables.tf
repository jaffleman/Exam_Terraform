
variable "namespace" { type = string }
variable "ami_id" { type = string } # AMI à utiliser
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "key_name" { type = string } # nom du key pair (pas le .pem)
variable "vpc_security_group_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "tg_arn" { type = string }    # Target Group ALB
variable "user_data" { type = string } # contenu script install_wordpress.sh
variable "ebs_device_name" {
  type    = string
  default = "/dev/xvdf"
}
variable "ebs_size_gb" {
  type    = number
  default = 10
}

# Capacité et scaling
variable "desired_capacity" {
  type    = number
  default = 1
}
variable "min_size" {
  type    = number
  default = 1
}
variable "max_size" {
  type    = number
  default = 3
}

# Politique de scaling (ex: target tracking CPU)
variable "enable_target_tracking" {
  type    = bool
  default = true
}
variable "cpu_target_utilization" {
  type    = number
  default = 45
}
