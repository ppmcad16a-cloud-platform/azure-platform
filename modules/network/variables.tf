variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "address_space" {
  description = "Whole IP range of the virtual network"
  type        = list(string)
}

variable "node_subnet_cidr" {
  description = "IP range for the Kubernetes nodes"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
