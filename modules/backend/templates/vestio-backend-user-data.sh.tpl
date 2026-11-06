#!/bin/bash
set -euxo pipefail

# System setup
yum update -y
yum install -y docker awscli amazon-cloudwatch-agent
systemctl enable --now docker

# App log directory (mounted into the container at /logs)
mkdir -p /var/log/vestio-backend
chmod 777 /var/log/vestio-backend

# NOTE: no Cognito credentials are baked here or injected as env vars.
# At startup the app fetches the Cognito configuration from Secrets Manager
# using its instance profile (default AWS credentials chain).

# Authenticate to ECR
aws ecr get-login-password --region ${aws_region} \
  | docker login --username AWS --password-stdin $(echo "${ecr_url}" | cut -d/ -f1)

# Pull and run the vestio-backend container
docker pull ${ecr_url}:${image_tag}
docker rm -f vestio-backend || true
docker run -d \
  --name vestio-backend \
  --restart always \
  -p ${host_port}:${app_port} \
  -v /var/log/vestio-backend:/logs \
  -e LOGGING_FILE_NAME=/logs/app.log \
  ${env_exports} \
  ${ecr_url}:${image_tag}
