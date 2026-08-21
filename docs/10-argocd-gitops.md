# 10 — ArgoCD and GitOps

## The core idea
Instead of CI running `kubectl apply` / `helm upgrade` against the
cluster directly, CI's only cluster-facing action is a git commit (bump
an image tag). ArgoCD, running *inside* the cluster, watches this repo
and reconciles the cluster to match what git says. Git becomes the single
source of truth for "what's actually running" — `git log` on this repo
*is* the deploy history, and rolling back a bad deploy is `git revert`,
not remembering the right `kubectl` incantation.

## App-of-Apps (`argocd/root-app.yaml`)
The only Application ever applied by hand (via
`ansible/playbooks/02-configure-argocd.yml` during initial cluster
bootstrap). Its own source is the `argocd/apps/` directory of this same
repo — every other Application, Project, and ApplicationSet is then
managed *by ArgoCD itself*. After bootstrap, "add an environment" or
"change a sync policy" is a git commit, never a manual `kubectl`/`argocd`
command against the live cluster.

## ApplicationSet (`argocd/apps/scalecart-environments-appset.yaml`)
A list generator turns one manifest into three real Applications
(`scalecart-dev`, `scalecart-staging`, `scalecart-prod`) — each deploying
the same `helm/scalecart-umbrella` chart with a different values file
layered on top (see docs/09-helm-charts.md). Adding a 4th environment is
one more list entry, not a new file to remember to keep in sync with the
other three.

## Why prod sync isn't automated
dev/staging have `automated: {prune: true, selfHeal: true}` — every merge
to main deploys immediately, because the blast radius of a bad dev/staging
deploy is low and fast feedback matters more. `scalecart-prod`'s
generated Application has `autoSync: "false"` — promotion to prod is a
deliberate `argocd app sync scalecart-prod` (CLI, or the UI's Sync
button) after verifying the change in staging, not an automatic side
effect of merging a PR.

## selfHeal
Even outside of syncs, ArgoCD continuously compares live cluster state to
git. If someone runs `kubectl edit deployment order-service` directly
against a `selfHeal: true` Application, ArgoCD reverts that change back
to what git specifies within minutes — this is what makes "the cluster
always matches git" an enforced property instead of a convention people
can quietly violate under incident pressure.

## PreSync hook (`helm/order-service/templates/presync-migration-job.yaml`)
Annotated `argocd.argoproj.io/hook: PreSync` — ArgoCD runs this Job (a
Flyway migration against the orders database, reading the same SQL
`.Files.Glob`-embedded into a ConfigMap) to completion *before* applying
the rest of the chart's resources on a sync. `hook-delete-policy:
HookSucceeded` cleans the Job up automatically once it passes. This adds
a stronger ordering guarantee on top of order-service's own
migrate-on-boot behavior (see docs/06-kubernetes-advanced.md) — belt and
suspenders, made safe to run twice by Flyway's own advisory locking.

## Platform vs. application Applications
`argocd/apps/platform-prod.yaml` (NetworkPolicy, Istio config, KEDA
ScaledObjects) is a deliberately separate Application from the per-service
umbrella chart. In a real org these have different owners (platform team
vs. app teams) and different risk profiles — bundling them means an
app-team's routine deploy could accidentally include a platform-team's
security-policy change (or vice versa), which is exactly what splitting
Applications by ownership boundary prevents.

## Rollback
Because the deployed state is defined entirely by git, rollback is
`git revert <bad commit>` + a sync (automatic for dev/staging, manual
`argocd app sync` for prod) — not remembering which `helm upgrade`
command undoes the last one.
