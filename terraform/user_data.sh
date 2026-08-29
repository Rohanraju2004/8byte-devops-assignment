#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y docker jq
systemctl enable --now docker

aws ecr get-login-password --region ${aws_region} \
  | docker login --username AWS --password-stdin ${ecr_repo_url}

SECRET=$(aws secretsmanager get-secret-value \
  --secret-id ${db_secret_arn} \
  --region ${aws_region} \
  --query SecretString --output text)

DB_USER=$(echo "$SECRET" | jq -r .username)
DB_PASS=$(echo "$SECRET" | jq -r .password)
DB_HOST=$(echo "${db_endpoint}" | cut -d: -f1)

docker run -d --restart always \
  -p ${app_port}:${app_port} \
  -e DB_HOST="$DB_HOST" \
  -e DB_USER="$DB_USER" \
  -e DB_PASSWORD="$DB_PASS" \
  -e DB_NAME="${db_name}" \
  -e DB_SSL=true \
  --name app \
  ${ecr_repo_url}:latest
  