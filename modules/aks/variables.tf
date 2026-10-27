variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "egress_ip" {
  description = "The NAT IP - the nodes reach the API server through it, so it must be allowed too"
  type        = string
}

variable "admin_cidrs" {
  description = "Who may talk to the Kubernetes API (kubectl)"
  type        = list(string)
}

variable "tenant_id" {
  type = string
}

variable "admin_object_ids" {
  description = "Entra ID users/groups that get cluster-admin rights"
  type        = list(string)
}

variable "vm_size" {
  type    = string
  default = "Standard_D2as_v5" # 2 vCPU, 8 GB RAM
}

variable "node_count" {
  description = "Free Trial quota is 4 vCPU -> 2 nodes of 2 vCPU"
  type        = number
  default     = 2
}

variable "os_disk_size_gb" {
  type    = number
  default = 64
}

variable "tags" {
  type    = map(string)
  default = {}
}
