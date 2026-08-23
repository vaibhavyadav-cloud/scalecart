# 15 — Security Hardening, Collected

Individual controls are documented next to the code that implements them;
this doc collects them into one defense-in-depth picture.

## Secrets never exist in plaintext outside AWS Secrets Manager
- Terraform's `random_password` generates every DB credential; it's
  written straight to Secrets Manager and marked `sensitive` in every
  output — never printed by `plan`/`apply`, never in a `.tf` file.
- The External Secrets Operator (`k8s/base/03-external-secrets.yaml`)
  syncs those values into native k8s `Secret` objects at runtime — no
  human ever copy-pastes a credential into a `kubectl create secret`
  command.
- Every AWS-facing credential is IRSA (`terraform/modules/iam`) — a pod
  assumes a role via its ServiceAccount and OIDC federation. No static
  AWS access key exists anywhere in this repo or cluster.

## Network segmentation, two layers
- `NetworkPolicy` (`k8s/base/02-network-policies.yaml`): default-deny,
  then explicit IP/port allows — coarse but cheap, and effective even for
  non-mesh-aware traffic (e.g. a Job).
- Istio `AuthorizationPolicy` (`k8s/istio/05-authorization-policies.yaml`):
  identity-aware (mTLS-verified SPIFFE identity), fine-grained — e.g.
  only the `order-service` ServiceAccount may call
  `product-service`'s stock-reservation endpoint. NetworkPolicy alone
  cannot express this; see docs/07 for the distinction.

## Encryption
- **In transit**: Istio `STRICT` mTLS mesh-wide
  (`k8s/istio/00-peer-authentication.yaml`); TLS from the browser to
  CloudFront/the ingress gateway; TLS to RDS/DocumentDB/ElastiCache/MSK
  (`transit_encryption_enabled`/equivalent set in every Terraform data
  module).
- **At rest**: `storage_encrypted = true` on RDS and DocumentDB,
  `at_rest_encryption_enabled = true` on ElastiCache, KMS encryption on
  ECR images and the S3 buckets.

## Container/runtime hardening
- Every container: non-root, read-only root filesystem, all Linux
  capabilities dropped, no privilege escalation
  (`common.securityContext` in `helm/common/templates/_helpers.tpl`).
- Multi-stage Docker builds keep dev tools and build toolchains out of
  the final runtime image entirely (docs/04) — fewer packages, less for
  Trivy to find, less for an attacker to use if a container is ever
  compromised.
- Distroless base image for `product-service` (no shell at all) — the
  strongest posture in the platform, chosen because Go's static binary
  makes it free to adopt.

## Supply chain
- Trivy scans every built image in CI, blocking on CRITICAL/HIGH CVEs
  (docs/11).
- An SBOM (CycloneDX) is generated and retained per build — "are we
  affected by CVE-X" becomes a lookup, not a re-scan.
- ECR images are tag-immutable (`terraform/modules/ecr`) — a tag, once
  pushed, can never be silently replaced.
- SonarQube's quality gate catches security *hotspots* in source (e.g. a
  string-concatenated query, a hardcoded secret pattern) that Trivy's
  image-level scanning can't see.

## IAM least privilege
Each service's IRSA role can read exactly *its own* secret in Secrets
Manager (`terraform/modules/iam`'s per-service `aws_iam_role_policy`) —
`auth-service`'s role has no path to `payment-service`'s database
credentials, enforced by IAM policy, not by convention or code review.

## What a real production rollout would still need on top of this
- A WAF in front of CloudFront/the ALB (rate limiting, bot mitigation) —
  not included here to keep the Terraform footprint focused on the
  services this project actually demonstrates.
- Automated secret rotation (Secrets Manager supports it natively for
  RDS; wiring the Lambda rotation function is a real next step).
- A formal threat model / pen test — appropriate for a real launch, out
  of scope for a portfolio build.
