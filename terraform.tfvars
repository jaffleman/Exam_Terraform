########################################################
# Identité et nommage
########################################################
namespace = "wp-rds"

########################################################
# Réseau VPC + Subnets (Paris eu-west-3)
########################################################
# CIDR global du VPC
vpc_cidr = "10.0.0.0/16"

# Deux subnets publics dans 2 AZ
public_subnet_cidrs = [
  "10.0.101.0/24", # eu-west-3a
  "10.0.102.0/24"  # eu-west-3b
]

# Deux subnets privés dans 2 AZ
private_subnet_cidrs = [
  "10.0.1.0/24", # eu-west-3a
  "10.0.2.0/24"  # eu-west-3b
]

# CIDR autorisé pour SSH (remplace TON_IP)
admin_cidr = "52.210.167.73/32"

########################################################
# Base de données MySQL (RDS)
########################################################
db_name     = "wordpress"
db_username = "wpuser"

# Instance RDS
rds_instance_class        = "db.t3.micro"
rds_allocated_storage     = 20
rds_max_allocated_storage = 100
backup_retention_days     = 7
multi_az                  = true

########################################################
# EC2 WordPress
########################################################
key_name = "Datascientest-Exam-ec2-paris"

########################################################
# Stockage EBS
########################################################
ebs_size_gb     = 10
ebs_device_name = "/dev/xvdf"
