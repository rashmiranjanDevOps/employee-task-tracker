environment = "prod"
aws_region  = "us-east-1"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnets     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
private_subnets    = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
database_subnets   = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]

eks_cluster_version = "1.33"

eks_node_groups = {
  general = {
    instance_types = ["m7i-flex.large"]
    min_size       = 3
    max_size       = 8
    desired_size   = 3
    capacity_type  = "ON_DEMAND"
    disk_size      = 50
  }
  spot = {
    instance_types = ["c7i-flex.large"]
    min_size       = 0
    max_size       = 10
    desired_size   = 2
    capacity_type  = "SPOT"
    disk_size      = 50
  }
}

rds_engine_version          = "8.0.46"
rds_instance_class          = "db.r6g.large"
rds_allocated_storage       = 100
rds_max_allocated_storage   = 500
rds_multi_az                = true
rds_database_name           = "tasktracker_prod"
rds_master_username         = "tasktracker_admin"
rds_backup_retention_period = 30
rds_deletion_protection     = true

domain_name = "rashmidevops.xyz"
# prod is the single source of truth for the shared hosted zone; all other
# environments leave manage_dns_zone at its default (false) and look up this
# zone instead of creating a duplicate one.
manage_dns_zone = true
acm_subject_alternative_names = [
  "app.rashmidevops.xyz",
  "api.rashmidevops.xyz",
  "grafana.rashmidevops.xyz",
  "argocd.rashmidevops.xyz",
]

waf_rate_limit = 2000

# Restrict EKS API access to known CIDRs — replace with your office/VPN CIDR(s)
eks_public_access_cidrs = ["23.20.113.163/32"]
