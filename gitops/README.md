# Employee Task Tracker — GitOps Repository

This directory mirrors what should live in a **separate** Git repository (e.g.
`employee-task-tracker-gitops`) consumed exclusively by ArgoCD. Keeping GitOps
config separate from application source code is a deliberate practice:

- **Separation of concerns:** App developers don't need write access to deployment config; SREs/DevOps own this repo.
- **Clean audit trail:** Every production change is a single, reviewable commit to this repo (often automated by CI).
- **Faster reconciliation:** ArgoCD only watches this small repo, not the full monorepo with source code.

## Structure

```
gitops/
├── apps/                          # ArgoCD Application + AppProject manifests
│   ├── argocd-project.yaml        # AppProject — RBAC, repo allow-list, sync windows
│   ├── app-of-apps.yaml           # Root "App of Apps" — discovers everything below
│   ├── task-tracker-prod.yaml     # Application: prod (manual prune, 1h alert repeat)
│   └── task-tracker-envs.yaml     # Applications: dev, qa, staging (auto-prune)
└── environments/
    ├── dev/        { Chart.yaml, values.yaml }   # Wraps helm/task-tracker chart
    ├── qa/         { Chart.yaml, values.yaml }
    ├── staging/    { Chart.yaml, values.yaml }
    └── prod/       { Chart.yaml, values.yaml }
```

Each `environments/<env>/Chart.yaml` is a thin Helm "umbrella chart" with a single
dependency on the real `task-tracker` chart (published from the **app repo's**
`helm/task-tracker`). In a real two-repo setup, the app repo publishes
`task-tracker` to a Helm OCI registry (e.g. ECR or ChartMuseum) on every merge to
`main`, and this repo's `Chart.yaml` pins a `version:`. The `file://../../../helm/task-tracker`
relative path here is for local development bundling only.

## How image tags get updated

Jenkins' **"Update GitOps Repo"** stage (see `jenkins/Jenkinsfile`) clones this
repo, patches `environments/<env>/values.yaml`'s `backend.image.tag` and
`frontend.image.tag` fields with the new commit SHA, commits, and pushes to
`main`. ArgoCD's `selfHeal: true` then reconciles the cluster automatically
(or waits for the configured sync window in prod).

## Promotion flow

```
feature branch → dev      (auto-sync, auto-prune)
qa branch       → qa       (auto-sync, auto-prune)
staging branch  → staging  (auto-sync, auto-prune)
main branch     → prod     (auto-sync, MANUAL prune, restricted sync window Mon–Fri 8am+8h)
```

## Secrets

No plaintext secret ever lives in this repo. `secrets:` blocks in each
`values.yaml` are placeholders; real values are injected at sync time by:

- **External Secrets Operator** pulling from AWS Secrets Manager (recommended), or
- **Sealed Secrets** (bitnami-labs/sealed-secrets) for fully GitOps-native encrypted secrets, or
- **Vault Agent Injector** sidecar pattern.

The Terraform `rds` module already writes DB credentials to
`task-tracker/<env>/db-credentials` in AWS Secrets Manager — point your ESO
`SecretStore`/`ExternalSecret` at that path.
