environment = "staging"
aws_region  = "us-east-1"

vpc_cidr           = "10.3.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnets     = ["10.3.0.0/24", "10.3.1.0/24", "10.3.2.0/24"]
private_subnets    = ["10.3.10.0/24", "10.3.11.0/24", "10.3.12.0/24"]
database_subnets   = ["10.3.20.0/24", "10.3.21.0/24", "10.3.22.0/24"]

eks_cluster_version = "1.33"

eks_node_groups = {
  general = {
    instance_types = ["c7i-flex.large"]
    min_size       = 2
    max_size       = 5
    desired_size   = 2
    capacity_type  = "ON_DEMAND"
    disk_size      = 50
  }
}

rds_engine_version          = "8.0.46"
rds_instance_class          = "db.t4g.medium"
rds_allocated_storage       = 50
rds_max_allocated_storage   = 150
rds_multi_az                = true
rds_database_name           = "tasktracker_staging"
rds_master_username         = "tasktracker_admin"
rds_backup_retention_period = 7
rds_deletion_protection     = true

domain_name = "rashmidevops.xyz"
# manage_dns_zone intentionally left unset (defaults to false): prod owns the
# shared hosted zone for this domain; this environment looks it up instead.
acm_subject_alternative_names = [
  "staging-app.rashmidevops.xyz",
  "staging-api.rashmidevops.xyz",
]

waf_rate_limit = 3000
