#!/usr/bin/env bash
# Bootstraps a fresh Amazon Linux 2023 EC2 instance to run the whole
# ScaleCart stack via docker-compose. Deliberately NOT Terraform/Ansible -
# this project's IaC (terraform/, ansible/) targets a full EKS cluster;
# this script is the separate, cheap "just get it running on one box"
# path documented in docs/19-ec2-deployment.md. Idempotent: safe to
# re-run if a step fails partway through.
#
# Run this FROM INSIDE the cloned repo, as the ec2-user:
#   git clone <your-fork-url> scalecart && cd scalecart
#   chmod +x scripts/ec2-bootstrap.sh && ./scripts/ec2-bootstrap.sh
set -euo pipefail

echo "==> Updating system packages"
sudo dnf update -y

echo "==> Installing Docker"
if ! command -v docker &>/dev/null; then
  sudo dnf install -y docker
fi
sudo systemctl enable --now docker
# Lets you run `docker`/`docker compose` without sudo after your next
# login (group membership only takes effect on a new shell session).
sudo usermod -aG docker "$USER"

echo "==> Installing the Docker Compose plugin"
if ! docker compose version &>/dev/null; then
  COMPOSE_VERSION="v2.29.2"
  mkdir -p ~/.docker/cli-plugins
  curl -fsSL \
    "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
    -o ~/.docker/cli-plugins/docker-compose
  chmod +x ~/.docker/cli-plugins/docker-compose
fi

echo "==> Installing git (if this script wasn't already cloned via git)"
sudo dnf install -y git

if [ ! -f .env ]; then
  echo "==> Creating .env from .env.example (edit this if you want non-default demo credentials)"
  cp .env.example .env
fi

echo "==> Building and starting the stack (this takes a few minutes the first time)"
# newgrp docker re-execs the rest of this script under the docker group
# without requiring a logout/login first - needed because usermod above
# doesn't affect the CURRENT shell session.
sg docker -c "docker compose up -d --build"

echo
echo "==> Done. Checking container status:"
sg docker -c "docker compose ps"

PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $(curl -s -X PUT 'http://169.254.169.254/latest/api/token' -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600')" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "<your-ec2-public-ip>")
echo
echo "Frontend should be reachable at: http://${PUBLIC_IP}:3000"
echo "Kafka UI (topic/consumer-lag inspection): http://${PUBLIC_IP}:8090"
echo "(Make sure your EC2 security group allows inbound TCP 3000 and 8090 - see docs/19-ec2-deployment.md)"
