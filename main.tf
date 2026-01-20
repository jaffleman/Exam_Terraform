terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}

# Suffixe aléatoire pour éviter toute collision sur le nom du DB Subnet Group
resource "random_id" "dbsg" {
  byte_length = 4
}

# ───────────────────────────
# 1) Réseau (VPC + subnets + IGW + NAT + routes + SG + DB Subnet Group)
# ───────────────────────────
module "networking" {
  source = "./modules/networking"

  namespace            = var.namespace
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = true

  create_database_subnet_group = true
  database_subnet_group_name   = "${var.namespace}-rds-private-subnets-${random_id.dbsg.hex}"

  admin_cidr = var.admin_cidr
}

# ───────────────────────────
# 2) RDS MySQL Multi-AZ (utilise le DB Subnet Group du module networking)
# ───────────────────────────
module "rds" {
  source = "./modules/rds"

  namespace            = var.namespace
  vpc_id               = module.networking.vpc_id
  db_subnet_group_name = module.networking.database_subnet_group_name
  web_sg_id            = module.networking.web_sg_id

  db_name               = var.db_name
  db_username           = var.db_username
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  backup_retention_days = var.backup_retention_days
  multi_az              = var.multi_az
}

# ───────────────────────────
# 3) EC2 WordPress (public_subnets[0]) + user_data (endpoint RDS injecté)
# ───────────────────────────
module "ec2" {
  source = "./modules/ec2"

  namespace = var.namespace
  subnet_id = module.networking.public_subnets[0]
  key_name  = var.key_name

  sg_ids = [
    module.networking.web_sg_id,
    module.networking.admin_ssh_sg_id
  ]

  user_data = templatefile("${path.root}/install_wordpress.sh", {
    DB_NAME     = var.db_name
    DB_USER     = var.db_username
    DB_PASS     = module.rds.db_password
    DB_HOST     = module.rds.endpoint
    MOUNT_POINT = "/var/www/html"
    DEVICE_NAME = var.ebs_device_name
  })
}

# ───────────────────────────
# 4) EBS (10 Go) dans la même AZ que l'EC2 + attachement
# ───────────────────────────
module "ebs" {
  source = "./modules/ebs"

  namespace         = var.namespace
  availability_zone = module.ec2.availability_zone
  size_gb           = var.ebs_size_gb
  device_name       = var.ebs_device_name
  instance_id       = module.ec2.instance_id
}


# ───────────────────────────
# 5) ALB + ACM + Listeners (module alb)
# ───────────────────────────
module "alb" {
  source = "./modules/alb"

  namespace         = var.namespace
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnets
  ec2_instance_ids  = [module.ec2.instance_id] # on attache ton instance WordPress
  https_fqdn        = var.https_fqdn
  health_check_path = var.health_check_path
}


# ───────────────────────────
# Outputs
# ───────────────────────────
output "vpc_id" { value = module.networking.vpc_id }
output "azs" { value = module.networking.azs }
output "public_subnets" { value = module.networking.public_subnets }
output "private_subnets" { value = module.networking.private_subnets }
output "public_route_table_ids" { value = module.networking.public_route_table_ids }
output "private_route_table_ids" { value = module.networking.private_route_table_ids }
output "igw_id" { value = module.networking.igw_id }
output "natgw_ids" { value = module.networking.natgw_ids }
output "database_subnet_group" { value = module.networking.database_subnet_group }

output "sg_web_id" { value = module.networking.web_sg_id }
output "sg_admin_ssh_id" { value = module.networking.admin_ssh_sg_id }

output "rds_endpoint" { value = module.rds.endpoint }
output "rds_port" { value = module.rds.port }
output "rds_db_name" { value = module.rds.db_name }
output "rds_db_username" { value = module.rds.db_username }
output "rds_db_password" {
  value     = module.rds.db_password
  sensitive = true
}
output "rds_identifier" { value = module.rds.identifier }
output "rds_arn" { value = module.rds.arn }

output "ec2_instance_id" { value = module.ec2.instance_id }
output "ec2_public_ip" { value = module.ec2.public_ip }
output "ec2_public_dns" { value = module.ec2.public_dns }
output "ec2_availability_zone" { value = module.ec2.availability_zone }

output "ebs_volume_id" { value = module.ebs.volume_id }
output "ebs_attachment_device_name" { value = module.ebs.attachment_device_name }
output "alb_dns_name" {
  description = "Nom DNS public de l'ALB"
  value       = module.alb.alb_dns_name
}

output "acm_dns_validation_records" {
  description = "CNAME à créer chez OVH pour valider le certificat"
  value       = module.alb.acm_dns_validation_records
}
