environment = "dev"
aws_region  = "us-east-1"

vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
public_subnets     = ["10.1.0.0/24", "10.1.1.0/24"]
private_subnets    = ["10.1.10.0/24", "10.1.11.0/24"]
database_subnets   = ["10.1.20.0/24", "10.1.21.0/24"]

eks_cluster_version = "1.33"

eks_node_groups = {
  general = {
    instance_types = ["c7i-flex.large"]
    min_size       = 1
    max_size       = 3
    desired_size   = 1
    capacity_type  = "ON_DEMAND"
    disk_size      = 30
  }
}

rds_engine_version          = "8.0.46"
rds_instance_class          = "db.t4g.micro"
rds_allocated_storage       = 20
rds_max_allocated_storage   = 50
rds_multi_az                = false
rds_database_name           = "tasktracker_dev"
rds_master_username         = "tasktracker_admin"
rds_backup_retention_period = 0
rds_deletion_protection     = false

domain_name = "rashmidevops.xyz"
# manage_dns_zone intentionally left unset (defaults to false): prod owns the
# shared hosted zone for this domain; this environment looks it up instead.
acm_subject_alternative_names = [
  "*.rashmidevops.xyz"
]

waf_rate_limit = 5000
