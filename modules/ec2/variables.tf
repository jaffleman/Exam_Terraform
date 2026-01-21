
variable "namespace" { type = string }
variable "subnet_id" { type = string }
variable "key_name" { type = string }

variable "sg_ids" {
  description = "Liste des SG (web + admin_ssh)"
  type        = list(string)
}

variable "user_data" {
  description = "Script d'initialisation (WordPress)"
  type        = string
}
