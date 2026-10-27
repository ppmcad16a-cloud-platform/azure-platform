variable "subscription_id" {
  type    = string
  default = "9c0602c2-72a4-4432-a192-7abf998e2b60"
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "admin_cidr" {
  description = "YOUR public IP as x.x.x.x/32 - set it in terraform.tfvars"
  type        = string
}
