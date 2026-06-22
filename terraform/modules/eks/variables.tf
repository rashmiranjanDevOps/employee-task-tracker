variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = string
    disk_size      = number
  }))
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the EKS public API endpoint. Restrict to office/VPN CIDRs in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
