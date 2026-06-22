variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (dev, qa, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, staging, prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "database_subnets" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
}

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.29"
}

variable "eks_node_groups" {
  description = "EKS managed node group configuration"
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = string
    disk_size      = number
  }))
  default = {
    general = {
      instance_types = ["t3.large"]
      min_size       = 2
      max_size       = 6
      desired_size   = 3
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
    }
    spot = {
      instance_types = ["t3.large", "t3a.large"]
      min_size       = 0
      max_size       = 6
      desired_size   = 2
      capacity_type  = "SPOT"
      disk_size      = 50
    }
  }
}

variable "rds_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0.46"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "Initial allocated storage (GB)"
  type        = number
  default     = 50
}

variable "rds_max_allocated_storage" {
  description = "Max storage for autoscaling (GB)"
  type        = number
  default     = 200
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "rds_database_name" {
  description = "Initial database name"
  type        = string
  default     = "tasktracker_prod"
}

variable "rds_master_username" {
  description = "Master DB username"
  type        = string
  default     = "tasktracker_admin"
}

variable "rds_backup_retention_period" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = "rashmidevops.xyz"
}

variable "manage_dns_zone" {
  description = <<-EOT
    Whether THIS environment's Terraform run owns and creates the shared
    Route53 hosted zone for domain_name. Only one environment (conventionally
    prod) should set this true in its terraform.tfvars. Every other
    environment must leave this false so it looks up the existing zone
    instead of creating a duplicate one — creating the same zone from
    multiple independent state files produces multiple hosted zones with
    different NS records and breaks DNS/ACM validation for whichever
    environments aren't actually delegated at the registrar.
  EOT
  type        = bool
  default     = false
}

variable "acm_subject_alternative_names" {
  description = "SANs for the ACM cert"
  type        = list(string)
  default = [
    "app.rashmidevops.xyz",
    "api.rashmidevops.xyz",
    "grafana.rashmidevops.xyz",
    "argocd.rashmidevops.xyz",
  ]
}

variable "waf_rate_limit" {
  description = "WAF rate limit (requests per 5 minutes per IP)"
  type        = number
  default     = 2000
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the EKS public API endpoint. Set to office/VPN CIDRs in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
