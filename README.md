# TaskFlow — Employee Task Tracker SaaS

A production-grade, multi-environment Employee Task Tracker built with React + Node.js/Express + MySQL, deployable to AWS EKS via Helm + ArgoCD with full CI/CD, observability, and security baked in from Day 1.

**Domain:** `rashmidevops.xyz`
| Service | URL |
|---|---|
| Frontend | https://app.rashmidevops.xyz |
| API | https://api.rashmidevops.xyz |
| Grafana | https://grafana.rashmidevops.xyz |
| ArgoCD | https://argocd.rashmidevops.xyz |

---

## 1. Architecture Overview

```
┌─────────────┐    ┌─────────────┐    ┌──────────────┐
│   Route53   │───▶│     WAF     │───▶│     ALB      │
└─────────────┘    └─────────────┘    └──────┬───────┘
                                              │
                          ┌───────────────────┴──────────────────┐
                          ▼                                      ▼
                 ┌─────────────────┐                  ┌─────────────────┐
                 │ Frontend (Nginx)│                  │ Backend (Node)  │
                 │  2-10 replicas  │                  │  2-10 replicas  │
                 └─────────────────┘                  └────────┬────────┘
                                                                │
                                                       ┌────────▼────────┐
                                                       │   RDS MySQL     │
                                                       │   (Multi-AZ)    │
                                                       └─────────────────┘
EKS Cluster (private subnets) | Monitoring: Prometheus + Grafana | GitOps: ArgoCD
```

## 2. Tech Stack

- **Frontend:** React 18, Vite, Tailwind CSS, Axios, React Router, Recharts
- **Backend:** Node.js 20, Express, Sequelize ORM, JWT auth, RBAC (admin/user)
- **Database:** MySQL 8.0 (AWS RDS compatible)
- **Containers:** Multi-stage Docker builds, non-root users, distroless-style minimal images
- **Orchestration:** Kubernetes (EKS) via Helm charts (dev/qa/staging/prod)
- **GitOps:** ArgoCD App-of-Apps pattern
- **CI/CD:** Jenkins (Checkout → Test → SonarQube → Trivy → Build → Push → GitOps → ArgoCD sync)
- **IaC:** Terraform (VPC, EKS, RDS, ALB, WAF, ACM, Route53)
- **Observability:** Prometheus, Grafana, Alertmanager → Slack

## 3. Repository Structure

```
employee-task-tracker/
├── backend/              # Express API (src/, Dockerfile, tests/)
├── frontend/             # React + Vite SPA
├── docker/               # docker-compose.yml for local dev
├── k8s/base/              # Raw Kubernetes manifests
├── helm/task-tracker/     # Helm chart (multi-env values)
├── gitops/                # ArgoCD Application manifests (App-of-Apps)
├── jenkins/Jenkinsfile    # CI/CD pipeline definition
├── monitoring/            # Prometheus rules + Grafana dashboards
├── terraform/             # AWS infra-as-code (modules + per-env tfvars)
└── scripts/                # Bootstrap & deploy helper scripts
```

## 4. Local Development (Docker Compose)

```bash
cd docker
docker compose up -d --build

# Seed sample data
docker compose exec backend npm run migrate
docker compose exec backend npm run seed
```

| Service     | URL                          |
|-------------|-------------------------------|
| Frontend    | http://localhost:3000         |
| Backend API | http://localhost:5000/api/v1  |
| Health      | http://localhost:5000/health  |
| Prometheus  | http://localhost:9090         |
| Grafana     | http://localhost:3001 (admin / GrafanaAdmin@123) |

Default seeded users (see `backend/src/config/seed.js`):
- `admin@rashmidevops.xyz` / `Admin@123456` (admin role)
- `alice@rashmidevops.xyz` / `User@123456` (user role)

## 5. Production Deployment (Step-by-Step for a 2+ yr DevOps Engineer)

### Step 1 — Provision AWS infrastructure
```bash
cd terraform
./../scripts/bootstrap-backend.sh prod us-east-1   # creates S3 + DynamoDB for state
terraform init -backend-config=environments/prod/backend.hcl
terraform plan  -var-file=environments/prod/terraform.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars
```
This creates: VPC (public/private/DB subnets across 3 AZs), NAT Gateways, IGW, EKS cluster + managed node groups (on-demand + spot), RDS MySQL (Multi-AZ, encrypted, automated backups), ACM cert (DNS-validated), WAF (rate limiting + AWS managed rule sets), ALB security group, Route53 hosted zone + records.

Repeat for `dev`, `qa`, `staging` using their respective tfvars/backend.hcl.

### Step 2 — Point your domain to Route53
After `terraform apply`, get the name servers:
```bash
terraform output route53_zone_id
aws route53 get-hosted-zone --id <zone-id>
```
Update your domain registrar's NS records for `rashmidevops.xyz` to the 4 AWS name servers shown.

### Step 3 — Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name task-tracker-prod
kubectl get nodes
```

### Step 4 — Install cluster add-ons
```bash
# AWS Load Balancer Controller (drives Ingress → ALB)
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=task-tracker-prod \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$(terraform output -raw -state=terraform/terraform.tfstate eks_cluster_name)"

# ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Prometheus + Grafana (kube-prometheus-stack) — or use monitoring/ assets directly
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

### Step 5 — Bootstrap ArgoCD App-of-Apps
```bash
kubectl apply -f gitops/apps/argocd-project.yaml
kubectl apply -f gitops/apps/app-of-apps.yaml
```
ArgoCD will pull `gitops/apps/*.yaml`, registering `task-tracker-dev/qa/staging/prod` Applications, each pointing at `environments/<env>` in the **separate GitOps repo** (`employee-task-tracker-gitops`). Push this repo's `helm/`, `k8s/` content into that GitOps repo structure (`environments/dev`, `environments/qa`, etc., each with their own `values.yaml` + `values-<env>.yaml`).

### Step 6 — Configure Jenkins
Create these Jenkins credentials (Manage Jenkins → Credentials):
`docker-registry-url`, `docker-registry-credentials`, `sonarqube-token`, `sonarqube-url`, `gitops-repo-credentials`, `argocd-server-url`, `argocd-auth-token`, `slack-webhook-url`.

Point a Multibranch Pipeline at this repo using `jenkins/Jenkinsfile`. Branch → environment mapping is defined in the `getDeployEnv()` helper (`main`→prod, `staging`→staging, `qa`→qa, else→dev).

### Step 7 — First deploy
Push to `main`. Jenkins will: install deps → lint → unit test → build frontend → SonarQube scan → npm audit → docker build → Trivy scan → docker push → update GitOps repo → `argocd app sync`.

Or deploy manually for a first pass:
```bash
./scripts/deploy.sh prod <image-tag>
```

### Step 8 — Verify
```bash
kubectl get pods -n task-tracker-prod
curl https://api.rashmidevops.xyz/health
curl https://app.rashmidevops.xyz
```

## 6. Security Checklist (already implemented)

- [x] JWT auth + refresh tokens, bcrypt (cost 12) password hashing, account lockout after 5 failed attempts
- [x] RBAC enforced server-side on every admin route
- [x] Helmet security headers, strict CORS allow-list, rate limiting (global + auth-specific)
- [x] express-validator input validation on all mutating routes
- [x] Audit log for every sensitive action (login, task CRUD, admin actions)
- [x] Non-root containers, read-only root FS (backend), dropped Linux capabilities
- [x] Kubernetes NetworkPolicy default-deny + explicit allow rules
- [x] Secrets via K8s Secret / AWS Secrets Manager — never committed to Git
- [x] TLS everywhere via ACM + ALB, HTTP→HTTPS redirect
- [x] AWS WAF: rate limiting, SQLi, XSS, known-bad-inputs, IP reputation managed rule groups
- [x] Least-privilege IAM via IRSA (per-service-account AWS roles)
- [x] RDS encryption at rest (KMS), encrypted backups, Multi-AZ in staging/prod
- [x] Trivy + npm audit + SonarQube gates in CI before any image is pushed

## 7. Environment Matrix

| Environment | Namespace             | Replicas (BE) | RDS                | Multi-AZ |
|-------------|------------------------|----------------|---------------------|----------|
| dev         | task-tracker-dev       | 1              | db.t3.micro         | No       |
| qa          | task-tracker-qa        | 1–2            | db.t3.small         | No       |
| staging     | task-tracker-staging   | 2              | db.t3.medium         | Yes      |
| prod        | task-tracker-prod      | 3–20 (HPA)     | db.r6g.large         | Yes      |

## 8. Runbooks

- **Pod crash-looping:** `kubectl logs -n task-tracker-prod <pod> --previous`; check `/ready` and `/live` probe history; check `kubectl describe pod`.
- **High error rate alert fired:** check Grafana → Application Overview → Error Rate panel; check recent ArgoCD sync / Jenkins deploys for correlated changes; consider `argocd app rollback`.
- **DB connection exhausted:** check `DB_POOL_MAX` vs RDS `max_connections`; review Grafana DB panel; check for long-running queries via RDS Performance Insights.
