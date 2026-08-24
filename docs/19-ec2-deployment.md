# 19 — Deploying to a Single EC2 Instance (Resume-Demo Path)

## What this is, and how it's different from the rest of this repo
Everything else in this repo (`terraform/`, `ansible/`, `k8s/`, `helm/`,
`argocd/`) targets a full production-shaped platform on EKS. That's the
right thing to build to *demonstrate* the skill — but it's not the
cheapest way to get a **live, clickable link** for a resume. This doc is
the other path: the exact same 7 services, same two database families,
same Kafka event flow, running via `docker-compose.yml` on **one EC2
instance** you already provisioned yourself. No new Terraform from this
project — you said you're doing that integration in a later stage, so
this is deliberately just SSH + Docker.

Assumptions for this guide (tell me if any of these are wrong):
- **Amazon Linux 2023** on the instance
- **t3.medium or larger** (2 vCPU / 4GB+ RAM) — the full stack (7 app
  containers + Postgres + MongoDB + Redis + Kafka + Kafka UI) needs that
  headroom to run without something getting OOM-killed
- You already have the instance running and can SSH into it

## Step 0 — Security group: open the ports you'll actually use
Your Terraform already created the instance and (presumably) its security
group. Before anything else, make sure inbound rules allow:

| Port | Purpose | Source |
|---|---|---|
| 22 | SSH | your IP only (`<your-ip>/32`) — never `0.0.0.0/0` for SSH |
| 3000 | Frontend (the app itself) | `0.0.0.0/0` if you want it publicly viewable for a resume link, otherwise your IP |
| 8090 | Kafka UI (optional, nice for showing off the async architecture live) | your IP, or skip if you don't want it public |

Via the AWS Console: **EC2 → your instance → Security → security group →
Edit inbound rules → Add rule** for each. Since you already have
Terraform managing this instance, if the security group is also
Terraform-managed, adding `3000` and `8090` there is one line in that
config — up to you whether to do it there or click it in the console for
now.

## Step 1 — SSH in
```bash
ssh -i /path/to/your-key.pem ec2-user@<ec2-public-ip>
```
(`ec2-user` is the default login for Amazon Linux 2023's AMI.)

## Step 2 — Get the code onto the instance
```bash
sudo dnf install -y git
git clone https://github.com/vaibhavyadav-cloud/scalecart.git
cd scalecart
```

## Step 3 — Run the bootstrap script
```bash
chmod +x scripts/ec2-bootstrap.sh
./scripts/ec2-bootstrap.sh
```

### What that script actually does (so you're not running something blind)
1. `dnf update -y` — patches the base AMI.
2. Installs Docker (`dnf install docker`), enables it as a systemd
   service so it **starts automatically on every reboot**
   (`systemctl enable --now docker`) — without this, a reboot would
   leave your demo down until someone manually starts Docker again.
3. Installs the Docker Compose v2 plugin directly from GitHub releases
   (Amazon Linux 2023's package repos don't ship it), placed in
   `~/.docker/cli-plugins/` — this is what makes `docker compose` (not
   the old standalone `docker-compose`) work.
4. Adds your user to the `docker` group so you don't need `sudo` for
   every docker command afterward.
5. Copies `.env.example` → `.env` if you don't already have one — the
   default values are fine for a demo; see "Security basics" below for
   when that stops being true.
6. Runs `docker compose up -d --build` — builds all 7 service images
   locally on the instance and starts the entire stack (same command as
   local dev, see docs/17-local-quickstart.md) — the first run takes a
   few minutes (compiling the Java/Go/TS builds); later restarts are
   fast since Docker caches layers.
7. Prints the instance's public IP and the URLs to check.

## Step 4 — Verify it's actually up
```bash
docker compose ps      # every service should show "Up" / "healthy"
docker compose logs -f --tail=50   # Ctrl+C to stop following
```
If a service shows `Restarting` repeatedly, jump to Troubleshooting
below before moving on.

## Step 5 — Open it in a browser
```
http://<ec2-public-ip>:3000
```
Register an account, browse the catalog, add to cart, place an order,
then watch `docker compose logs -f payment-service notification-service`
in your SSH session while you refresh the order's status page — you'll
see the Kafka consumer pick up the event in real time. That live moment
is the actual payoff of this whole demo for an interview.

Kafka UI (topic/partition/consumer-lag inspection - genuinely useful to
show off in an interview): `http://<ec2-public-ip>:8090`

## Step 6 (optional, but worth it for a resume link) — A real domain + HTTPS
`http://54.201.x.x:3000` works, but `https://scalecart.yourdomain.com`
reads a lot better on a resume. If you own a domain:

1. Point an A record at your EC2's public IP (or better, an Elastic IP —
   see Cost notes below, a plain public IP changes if you stop/start the
   instance).
2. Install Nginx as a reverse proxy in front of docker-compose's frontend
   container, terminating TLS:
   ```bash
   sudo dnf install -y nginx
   sudo systemctl enable --now nginx
   ```
3. Point a server block at the frontend container's exposed port:
   ```nginx
   # /etc/nginx/conf.d/scalecart.conf
   server {
       listen 80;
       server_name scalecart.yourdomain.com;
       location / {
           proxy_pass http://localhost:3000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```
4. Get a free cert with certbot:
   ```bash
   sudo dnf install -y certbot python3-certbot-nginx
   sudo certbot --nginx -d scalecart.yourdomain.com
   ```
   Certbot rewrites the Nginx config to redirect HTTP→HTTPS and auto-
   renews via a systemd timer it installs — nothing else to maintain.
5. Update your security group: you can now close port 3000 to the public
   internet (Nginx on 80/443 is the only thing that needs to be open;
   `proxy_pass http://localhost:3000` still works since Nginx and Docker
   are on the same host).

## Cost optimization (you said this matters)
- **Stop the instance when you're not actively demoing it.** `docker
  compose`'s `restart: unless-stopped` policy means everything comes back
  up automatically the moment you start the instance again — no manual
  steps. A stopped t3.medium costs nothing in compute (you still pay a
  small amount for the attached EBS volume).
- **Don't attach an Elastic IP unless you set up the domain in Step 6.**
  A stopped/started instance gets a new public IP each time otherwise,
  which is fine if you just re-check the IP before each demo session; an
  Elastic IP costs a small hourly fee *only* while it's NOT attached to a
  running instance (i.e., it's actually free while the instance is up,
  and there's a small charge if you stop the instance while still holding
  it — factor that in if you go this route).
- **EBS volume**: 20-30GB gp3 is enough for the OS + all 7 Docker images
  + Postgres/Mongo data. gp3 is cheaper per-GB than the older gp2 default
  some AMIs still pick — worth checking what your Terraform provisioned.
- **Don't run this instance as a permanent Terraform target in `terraform/envs/prod`
  at the same time.** This EC2 path and the EKS path in this repo are two
  independent demos of the same codebase — running both simultaneously
  just doubles your AWS bill for no additional resume value.

## Security basics for a public demo
This is a portfolio demo, not a real business, so the bar here is "don't
accidentally leak something," not "SOC 2 compliant":
- The default `.env`/Prisma `JWT_SECRET` and DB passwords are fine for a
  demo **as long as you don't put real personal data into it**. Don't
  reuse a real password when you register a test account.
- Keep SSH (port 22) restricted to your own IP, always — this is the one
  rule worth being strict about even for a throwaway demo box.
- If you stop caring about the demo, `docker compose down -v` (removes
  volumes too) before terminating the instance, so old data doesn't
  linger on a detached EBS snapshot somewhere.

## Troubleshooting
- **A container keeps restarting** → `docker compose logs <service>`.
  The most common cause on a t3.medium-class box is `order-service`
  (the JVM) or `kafka` needing a moment longer to become healthy than
  their `depends_on` healthcheck allows on a slower/smaller instance —
  give it another minute and check again before assuming it's broken.
- **Out of memory / a container gets silently killed** →
  `docker stats` to see per-container memory, and `free -h` for the
  host. If you're on a smaller instance than t3.medium, the honest fix
  is a bigger instance, not squeezing this stack further — 7 services +
  4 datastores genuinely needs the headroom.
- **Can't reach `<ip>:3000` from your browser** → 95% of the time this is
  the security group, not Docker. Confirm the inbound rule from Step 0
  actually saved, and confirm you're using the instance's *public* IP,
  not its private one.
- **Disk fills up over time** → `docker system prune -f` reclaims space
  from old build layers/dangling images; `docker compose build` on every
  re-deploy accumulates these.
