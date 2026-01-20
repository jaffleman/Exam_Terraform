
variable "namespace" {
  description = "Préfixe de nommage (même que le reste du projet)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (module.networking.vpc_id)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Subnets publics (module.networking.public_subnets)"
  type        = list(string)
}

variable "ec2_instance_ids" {
  description = "Instances EC2 à attacher au Target Group (au minimum ton instance WordPress)"
  type        = list(string)
}

variable "https_fqdn" {
  description = "FQDN public à sécuriser (ex: exam-terraform.jaffleman.tech)"
  type        = string
}

variable "health_check_path" {
  description = "Chemin de health-check HTTP côté EC2"
  type        = string
  default     = "/"
}
