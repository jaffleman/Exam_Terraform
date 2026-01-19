
variable "namespace" { type = string }
variable "vpc_id" { type = string }
variable "db_subnet_group_name" { type = string } # vient du module networking
variable "web_sg_id" { type = string }            # SG WordPress (pour autoriser 3306)

variable "db_name" { type = string }
variable "db_username" { type = string }

variable "instance_class" { type = string }
variable "allocated_storage" { type = number }
variable "max_allocated_storage" { type = number }
variable "backup_retention_days" { type = number }
variable "multi_az" { type = bool }

variable "deletion_protection" {
  description = "Protection suppression (prod: true)"
  type        = bool
  default     = false
}
