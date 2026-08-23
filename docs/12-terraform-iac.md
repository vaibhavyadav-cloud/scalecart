# 12 — Terraform: Infrastructure as Code

## Module layout
```
terraform/modules/
  network/            VPC, subnets (3 AZ), NAT gateways, route tables
  eks/                EKS control plane + OIDC provider + baseline managed node group
  rds-postgres/       reusable - instantiated 3x (auth, orders, payments)
  documentdb/         MongoDB-compatible cluster for product-service
  elasticache-redis/  Redis replication group for cart/notification
  msk/                managed Kafka (prod path only - see docs/08)
  ecr/                7 container repos, immutable tags, lifecycle policy
  s3-cloudfront/      static frontend hosting/CDN + CI artifacts bucket
  iam/                IRSA roles per service + cluster add-on roles
terraform/envs/
  dev/                wires the modules together for a cheap, single-AZ-failover-tolerant dev stack
  prod/                wires the modules together for the full HA/Multi-AZ topology
```

## Why modules instead of one big root config
`rds-postgres` is written once and instantiated three times (`auth_db`,
`orders_db`, `payments_db` in `envs/prod/main.tf`) with different
`database_name`/`read_replica_count` inputs — this is the Terraform
equivalent of the Helm library chart pattern (docs/09): the *shape* of "a
Postgres instance with encryption, a subnet group, a security group, and
its credentials in Secrets Manager" is defined once, and each environment
config just supplies the values that differ.

## Dev vs. prod, and why each difference exists
| | dev | prod | why |
|---|---|---|---|
| RDS Multi-AZ | off | on | dev doesn't need automatic failover; the cost isn't justified for a non-customer-facing environment |
| RDS read replicas | 0 | 1 (orders only) | only orders' read pattern (order history pages) is proven to need it — see docs/14 |
| Kafka | in-cluster Strimzi | Amazon MSK | dev/demo shouldn't require MSK's setup time/cost; prod wants a managed, SLA-backed broker |
| Node group floor | 2× t3.large | 3× m6i.large | prod's floor covers steady-state traffic without waiting on Karpenter to react |
| CloudFront/S3 | not provisioned | provisioned | dev serves the frontend via the in-cluster Nginx Deployment only |

## State management
Remote state in S3, locked via a DynamoDB table (`versions.tf` in each
env) — without a lock, two concurrent `terraform apply` runs (a person
and a CI run, or two people) can corrupt state. The S3 bucket + DynamoDB
table themselves are bootstrapped once, by hand, before any environment's
backend block can be used — Terraform can't create the backend it's about
to store its own state in.

## Secrets never touch a `.tf` file or Terraform state's plaintext output
Every module that creates a database generates its own password
(`random_password`) and immediately writes it to AWS Secrets Manager —
the value is marked `sensitive` in outputs and is never printed by
`terraform plan`/`apply`, never committed, and is read at runtime by the
External Secrets Operator (k8s/base/03-external-secrets.yaml), not by
anything Terraform-adjacent.

## Validating without touching a real AWS account
`terraform validate` (with `-backend=false`) needs no credentials at all
— that's what `.github/workflows/terraform.yml`'s `validate` job and
`make tf-validate` both run. `terraform plan` (in CI, or locally) does
need real AWS credentials, obtained via OIDC federation in CI (no stored
access keys) — see docs/11-github-actions-cicd.md.
