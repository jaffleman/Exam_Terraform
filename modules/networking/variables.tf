
variable "namespace" {
  description = "Préfixe de nommage"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR du VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDRs des subnets publics"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs des subnets privés"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Activer NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Un seul NAT Gateway (éco)"
  type        = bool
  default     = true
}

variable "create_database_subnet_group" {
  description = "Créer un DB Subnet Group"
  type        = bool
  default     = true
}

variable "database_subnet_group_name" {
  description = "Nom du DB Subnet Group"
  type        = string
  default     = null
}

variable "admin_cidr" {
  description = "CIDR autorisé pour SSH"
  type        = string
}
