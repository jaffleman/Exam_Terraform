
variable "namespace" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "admin_cidr" { type = string } # ex: "203.0.113.10/32"

# DB
variable "db_name" {
  type    = string
  default = "wordpress"
}
variable "db_username" {
  type    = string
  default = "wpuser"
}
variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "rds_allocated_storage" {
  type    = number
  default = 20
}
variable "rds_max_allocated_storage" {
  type    = number
  default = 100
}
variable "backup_retention_days" {
  type    = number
  default = 7
}
variable "multi_az" {
  type    = bool
  default = true
}

# EC2 + EBS
variable "key_name" { type = string }
variable "ebs_size_gb" {
  type    = number
  default = 10
}
variable "ebs_device_name" {
  type    = string
  default = "/dev/xvdf"
}
