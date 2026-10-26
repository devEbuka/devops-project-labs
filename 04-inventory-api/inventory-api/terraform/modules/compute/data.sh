#!/bin/bash

set -euo pipefail

AWS_ACCOUNT_ID="${aws_account_id}"
AWS_REGION="${aws_region}"
ECR_REGISTRY="$${AWS_ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com"
ECR_REPOSITORY_URL="${ecr_repository_url}"

# Add Docker's official GPG key:
apt-get update
apt-get install -y ca-certificates curl unzip python3
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
systemctl is-active --quiet docker

curl -fSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Verify SSM Agent is running
if snap list amazon-ssm-agent >/dev/null 2>&1; then
  snap start amazon-ssm-agent
  snap services amazon-ssm-agent
else
  echo "WARNING: SSM Agent snap is not installed"
fi
