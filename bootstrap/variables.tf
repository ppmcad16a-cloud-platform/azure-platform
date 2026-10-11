variable "subscription_id" {
  type    = string
  default = "9c0602c2-72a4-4432-a192-7abf998e2b60"
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "github_org" {
  type    = string
  default = "ppmcad16a-cloud-platform"
}

variable "github_repo" {
  type    = string
  default = "azure-platform"
}

variable "budget_amount" {
  description = "Monthly budget in the subscription's billing currency (10 if USD, ~850 if INR)"
  type        = number
  default     = 10
}

variable "budget_start_date" {
  description = "First day of the current month (Azure requires this)"
  type        = string
  default     = "2026-10-01T00:00:00Z"
}

variable "alert_email" {
  type    = string
  default = "rishav1994sonai@gmail.com"
}
