# 13 — Ansible: Configuration Management on Top of Terraform

## Why Ansible exists here at all, given EKS is fully managed
There are no application servers to SSH into in this platform — every
workload is a pod on EKS. That's worth saying explicitly, because it
means Ansible's *classic* job (configuring long-lived VMs) mostly doesn't
apply here. What's left, and what these playbooks actually do, is the
**day-1 cluster software bootstrap**: after Terraform creates a bare EKS
cluster, *something* has to install metrics-server, the AWS Load Balancer
Controller, Karpenter, External Secrets, Istio, KEDA, and ArgoCD onto it
before any application can run. That's genuinely configuration
management, just against the Kubernetes API instead of SSH — every task
in `ansible/roles/` uses `kubernetes.core.helm` / `kubernetes.core.k8s`,
not `ansible.builtin.copy` to a remote filesystem.

## The IaC / CM boundary, drawn explicitly
| Layer | Owns | Tool |
|---|---|---|
| Cloud resources (VPC, EKS control plane, RDS, IAM roles) | Terraform | `terraform/` |
| Software running inside the cluster (Istio, ArgoCD, KEDA, Karpenter...) | Ansible | `ansible/` |
| Application workloads (the 7 services) | Helm + ArgoCD | `helm/`, `argocd/` |

Terraform's own state has no idea what's installed *inside* the cluster
it created — asking Terraform to also manage `helm_release` resources for
every add-on is possible, but couples cluster bootstrap to Terraform's
apply/plan cadence and blast radius. Ansible is a deliberately separate,
run-once-at-bootstrap tool for exactly that reason.

## Run order (each depends on the previous step's output)
1. `00-bootstrap-tools.yml` — installs kubectl/helm/istioctl/argocd CLI
   locally. Run on any machine before it operates the cluster.
2. `01-install-cluster-addons.yml` — takes Terraform's outputs
   (`eks_cluster_name`, `vpc_id`, the IRSA role ARNs from
   `terraform/modules/iam`) as input variables and installs every add-on
   the application layer assumes exists (metrics-server for HPA to
   function at all, Istio for the mesh, KEDA for the two Kafka consumers,
   External Secrets so `k8s/base/03-external-secrets.yaml` has an
   operator to reconcile it, Strimzi *only* in envs that don't use MSK).
3. `02-configure-argocd.yml` — installs ArgoCD, then applies
   `argocd/root-app.yaml`. This is the last manual step in the whole
   pipeline; everything after it is GitOps (docs/10).

## Idempotency
Every task is written to be safely re-runnable: `get_url`/`unarchive`
with `creates:`/`force: false` skip re-downloading an already-present
binary, and `kubernetes.core.helm`/`k8s` modules are declarative — running
`01-install-cluster-addons.yml` again after a Helm chart version bump
just upgrades the release in place, it doesn't fail because "the release
already exists."

## Passing Terraform outputs into Ansible
```
ansible-playbook playbooks/01-install-cluster-addons.yml \
  -e "eks_cluster_name=$(terraform -chdir=terraform/envs/prod output -raw eks_cluster_name)" \
  -e "lb_controller_role_arn=$(terraform -chdir=terraform/envs/prod output -json irsa_role_arns | jq -r .lb_controller)" \
  ...
```
This is the literal seam between the two tools — Terraform's `output`
command, piped as `-e` vars into the Ansible run.
