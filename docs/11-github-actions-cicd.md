# 11 — GitHub Actions CI/CD

## Why one reusable workflow instead of 7 near-identical ones
`.github/workflows/reusable-build-scan-push.yml` holds the entire
pipeline shape; each `ci-<service>.yml` is ~10 lines that just supply
`service_name`, `service_path`, and `language`. Fixing or improving the
pipeline (say, tightening the Trivy severity gate) is a one-file change,
not a 7-file find-and-replace — same DRY reasoning as the Helm library
chart (docs/09) and the platform contract every service implements
(docs/02).

## The stages, in order, and why that order
1. **Lint** — cheapest possible failure, fails in seconds before spending
   any time on slower steps.
2. **Test + coverage** — each service's own test suite (docs/02's "every
   service has real tests" — auth-service's password validation, cart-
   service's Redis-backed cart logic via `fakeredis`, order-service's full
   Spring context integration test with an embedded Kafka broker, etc).
3. **SonarQube scan + quality gate** — static analysis (code smells,
   duplicated code, security hotspots) plus the coverage numbers from
   step 2. `sonarqube-quality-gate-action` actually **fails the job** if
   the project's configured quality gate isn't met — this is a gate, not
   a dashboard nobody opens.
4. **Docker build + push** (to GHCR, tagged with both the git SHA and
   `latest`) — only reached if 1-3 passed.
5. **Trivy scan** of the exact image just pushed, `exit-code: 1` on any
   CRITICAL/HIGH CVE — fails the job and uploads results to GitHub's
   Security tab (via SARIF) either way, so even a "soft" informational
   run is visible to the team.
6. **SBOM generation** (Syft, CycloneDX format) — lets anyone later
   answer "does image X contain vulnerable package Y" without re-scanning
   the image from scratch; increasingly a compliance ask, cheap to
   produce here since the image is already local.
7. **Upload artifacts** — coverage report, Trivy SARIF, and the SBOM, all
   retained 90 days as downloadable GitHub Actions artifacts. This is the
   audit trail: "what did we ship, and how do we know it was safe."
8. **GitOps tag bump** — the *only* step that touches deployment state,
   and it does so with a `git commit` to `helm/scalecart-umbrella/values-dev.yaml`,
   not `kubectl`/`helm upgrade` run from CI. ArgoCD picks the commit up
   and does the actual deploy — see docs/10-argocd-gitops.md for why CI
   never talks to the cluster directly.

## Why Trivy scans the image, not the source
Source-level dependency scanning (e.g. `npm audit`) only sees what's in
`package.json`. Trivy scans the *built image* — every OS package and
transitive dependency actually baked into the final layer — which is why
docs/04-docker-optimization.md's multi-stage builds matter here directly:
fewer packages in the runtime image means fewer things for Trivy to find.

## Why Terraform gets its own separate workflow
`.github/workflows/terraform.yml` never runs alongside the app pipelines
— infrastructure changes have a different blast radius (a bad Terraform
apply can take down the whole cluster, not just one service) and a
different review process (a `environment: prod` gate requiring a human
approval click, via GitHub's Environments feature, before `terraform
apply` runs against the prod AWS account). Terraform PRs also get the
`terraform plan` output posted as a PR comment, so reviewers see the
*exact* infrastructure diff, not just the `.tf` code diff. See
docs/12-terraform-iac.md.

## No long-lived AWS credentials in GitHub
Both the plan and apply jobs use `aws-actions/configure-aws-credentials`
with OIDC federation (`role-to-assume`) — GitHub Actions requests a
short-lived AWS credential by presenting a signed OIDC token, and IAM
trusts it based on the repo/branch. No AWS access key is ever stored as a
GitHub secret.
