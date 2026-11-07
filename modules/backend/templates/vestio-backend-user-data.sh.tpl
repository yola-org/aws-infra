#!/bin/bash
set -euo pipefail

# System setup
yum update -y
yum install -y docker awscli amazon-cloudwatch-agent
systemctl enable --now docker

# App log directory (mounted into the container at /logs)
mkdir -p /var/log/vestio-backend
chmod 777 /var/log/vestio-backend

# Fetch the allowlisted secrets from Secrets Manager using the instance
# profile. Only secret names are baked into the launch template; the values are
# written to a root-only env file so they never appear in user-data, cloud-init
# logs or the docker command line. Do not add `set -x` to this script.
SECRET_NAME_PREFIX="${secret_name_prefix}"
SECRET_NAMES=(
%{ for name in secret_names ~}
  "${name}"
%{ endfor ~}
)

ENV_FILE=/etc/vestio-backend.env
install -m 600 /dev/null "$ENV_FILE"

for secret_name in "$${SECRET_NAMES[@]}"; do
  # Strip the environment prefix to get the Spring Boot key.
  env_name="$${secret_name#$${SECRET_NAME_PREFIX}}"

  if [ "$env_name" = "$secret_name" ]; then
    echo "Secret $secret_name does not start with $SECRET_NAME_PREFIX" >&2
    exit 1
  fi

  secret_value="$(aws secretsmanager get-secret-value \
    --region "${aws_region}" \
    --secret-id "$secret_name" \
    --query SecretString \
    --output text)"

  printf '%s=%s\n' "$env_name" "$secret_value" >> "$ENV_FILE"
done

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
