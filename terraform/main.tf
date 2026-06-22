terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # Configured per-environment via backend-config files
    # terraform init -backend-config=environments/prod/backend.hcl
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "task-tracker"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "devops-team"
    }
  }
}

data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# ─── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  database_subnets   = var.database_subnets
  cluster_name       = local.cluster_name
}

# ─── EKS ───────────────────────────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  environment        = var.environment
  cluster_name       = local.cluster_name
  cluster_version    = var.eks_cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  node_groups          = var.eks_node_groups
  public_access_cidrs  = var.eks_public_access_cidrs
}

# ─── RDS MySQL ──────────────────────────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  environment           = var.environment
  identifier            = "${local.cluster_name}-mysql"
  vpc_id                = module.vpc.vpc_id
  database_subnet_ids   = module.vpc.database_subnet_ids
  allowed_security_groups = [module.eks.node_security_group_id]

  engine_version        = var.rds_engine_version
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  multi_az              = var.rds_multi_az
  database_name         = var.rds_database_name
  master_username        = var.rds_master_username
  backup_retention_period = var.rds_backup_retention_period
  deletion_protection   = var.rds_deletion_protection
}

# ─── Route53 Hosted Zone (no ALB dependency — breaks acm/alb cycle) ────────────
module "route53_zone" {
  source = "./modules/route53-zone"

  domain_name = var.domain_name
  manage_zone = var.manage_dns_zone
}

# ─── ACM Certificate ────────────────────────────────────────────────────────────
module "acm" {
  source = "./modules/acm"

  domain_name               = var.domain_name
  subject_alternative_names = var.acm_subject_alternative_names
  route53_zone_id           = module.route53_zone.zone_id
}

# ─── Route53 Records (ALB aliases — created after the ALB exists) ──────────────
module "route53" {
  source = "./modules/route53"

  domain_name  = var.domain_name
  environment  = var.environment
  zone_id      = module.route53_zone.zone_id
  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id
}

# ─── WAF ────────────────────────────────────────────────────────────────────────
module "waf" {
  source = "./modules/waf"

  environment  = var.environment
  name_prefix  = local.cluster_name
  alb_arn      = module.alb.alb_arn
  rate_limit   = var.waf_rate_limit
}

# ─── ALB (created by AWS Load Balancer Controller, but base SG + target groups here) ──
module "alb" {
  source = "./modules/alb"

  environment       = var.environment
  name_prefix       = local.cluster_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.acm.certificate_arn
}

locals {
  cluster_name = "task-tracker-${var.environment}"
}
