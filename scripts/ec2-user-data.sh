#!/bin/bash
# Paste this into "User data" when launching the EC2 instance (Ubuntu 24.04).
# It installs Docker, downloads the project and starts it on port 80.
set -eux

apt-get update -y
apt-get install -y docker.io docker-compose-v2 git openssl curl
systemctl enable --now docker
usermod -aG docker ubuntu

git clone https://github.com/ArpitaSethi-12/devsecops-pipeline.git /opt/app
cd /opt/app

# Random database password, kept only on this server
echo "DB_PASSWORD=$(openssl rand -hex 16)" > .env
echo "APP_VERSION=$(git rev-parse --short HEAD)" >> .env
chmod 600 .env

docker compose -f docker-compose.prod.yml up -d --build
