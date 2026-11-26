# EKS Preview Lab: Infrastructure

Terraform and the shared GitHub Actions workflows for the **EKS Preview Lab**. The **platform side** lives here:
- VPC and EKS;
- IAM and GitHub OIDC;
- remote state;
- the per-PR environment module;
- the reusable `preview` / `teardown` workflows.

The application it deploys lives in **[elad1122/eks-preview-lab](https://github.com/elad1122/eks-preview-lab)**.

> 🚧 Work in progress. This repo is built step by step following the [plan](https://github.com/elad1122/eks-preview-lab/blob/main/docs/PLAN.md). Why there are two repos, and how they connect, is explained in [docs/REPOSITORIES.md](https://github.com/elad1122/eks-preview-lab/blob/main/docs/REPOSITORIES.md) in the app repo.

## Layout (target)

```
eks-preview-lab-infra/
├── bootstrap/          # Plan steps 2–3: state bucket, GitHub OIDC provider, gha-* roles, permission boundary
├── modules/
│   ├── vpc/            # Step 4: 2 AZs, public + private subnets, no NAT (cost trade-off)
│   └── eks/            # Step 5: cluster, Spot node group, add-ons, access entries, LB controller
├── envs/
│   ├── platform/       # Steps 5–6: modules/vpc + modules/eks + the ECR repo (applied from main)
│   └── preview/        # Step 7: one per PR. pr_number → bucket, IAM role, Pod Identity, namespace
└── .github/workflows/
    ├── infra-ci.yml    # fmt / validate / tflint / checkov / plan on PRs to this repo
    ├── apply.yml       # apply envs/platform on merge to main               (step 8)
    ├── preview.yml     # REUSABLE: called by the app repo on PR open/sync  (step 8)
    ├── teardown.yml    # REUSABLE: called by the app repo on PR close      (step 8)
    └── reaper.yml      # nightly cleanup of leftover pr-* environments     (step 9)
```

## The contract with the app repo

`preview.yml` deploys the app repo's Helm chart (`chart/preview-app`) with these values:

| Chart value | Comes from |
|---|---|
| `image.repository` / `image.tag` | ECR repo URL from `envs/platform` / the PR's commit SHA |
| `env.name`, `basePath` | `pr-<N>`, `/pr-<N>` |
| `env.gitSha` | The PR's commit SHA |
| `notesBucket` | The bucket `envs/preview` created |
| `serviceAccount.name` | Must equal the service account in `aws_eks_pod_identity_association` (default `preview-app`) |
| `ingress.enabled=true` | Needs the AWS Load Balancer Controller from `modules/eks` |

The app repo calls the reusable workflows like this:

```yaml
# eks-preview-lab/.github/workflows/preview.yml
on:
  pull_request:
    types: [opened, synchronize, reopened]
jobs:
  preview:
    uses: elad1122/eks-preview-lab-infra/.github/workflows/preview.yml@main
    permissions: { id-token: write, contents: read, pull-requests: write }
```

## Session routine

```bash
aws login --remote
cd envs/platform && terraform apply      # about 12–15 minutes for EKS
# ... work ...
terraform destroy                        # before you stop. Do not skip.
```
