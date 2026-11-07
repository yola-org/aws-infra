#!/bin/bash
set -euo pipefail

# System setup
yum update -y
yum install -y docker awscli amazon-cloudwatch-agent
systemctl enable --now docker

# App log directory (mounted into the container at /logs)
mkdir -p /var/log/vestio-backend
chmod 777 /var/log/vestio-backend

# Fetch the allowlisted secrets from Secrets Manager using the instance profile.
# Only secret names and their target environment-variable names are baked into
# the launch template; values are written to a root-only env file so they never
# appear in user-data, cloud-init logs or the docker command line. Do not add
# `set -x` to this script.
ENV_FILE=/etc/vestio-backend.env
install -m 600 /dev/null "$ENV_FILE"

%{ for env_name, secret_name in secret_names ~}
  secret_value="$(aws secretsmanager get-secret-value \
    --region "${aws_region}" \
    --secret-id ${jsonencode(secret_name)} \
    --query SecretString \
    --output text)"

  printf '${env_name}=%s\n' "$secret_value" >> "$ENV_FILE"
%{ endfor ~}

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
  --env-file "$ENV_FILE" \
  ${env_exports} \
  ${ecr_url}:${image_tag}
