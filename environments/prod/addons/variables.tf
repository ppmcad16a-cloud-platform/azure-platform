variable "subscription_id" {
  type    = string
  default = "9c0602c2-72a4-4432-a192-7abf998e2b60"
}

variable "cluster_name" {
  type    = string
  default = "prod-aks"
}

variable "cluster_resource_group" {
  type    = string
  default = "rg-prod-cluster"
}

variable "admin_cidr" {
  description = "YOUR public IP x.x.x.x/32 - may reach the front door directly for testing"
  type        = string
}

variable "envoy_gateway_version" {
  type    = string
  default = "v1.9.2"
}

variable "external_secrets_version" {
  type    = string
  default = "2.12.0"
}

variable "app_secret_names" {
  description = "Key Vault secrets the cluster may read (created by global-platform)"
  type        = list(string)
  default = [
    "mern-mongo-uri",
    "mern-jwt-secret",
    "mern-seed-admin-password",
    "mern-origin-tls-crt",
    "mern-origin-tls-key",
    "mern-slack-webhook-url", # Alertmanager -> Slack
  ]
}
