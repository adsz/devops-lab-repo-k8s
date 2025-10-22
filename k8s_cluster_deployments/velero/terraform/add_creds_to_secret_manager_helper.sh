#!/usr/bin/env bash

# Helper: push Telegram credentials from env vars into Secrets Manager
# Usage:
#   export TELEGRAM_TOKEN="..."
#   export TELEGRAM_CHAT_ID="..."
#   ./add_creds_to_secret_manager_helper.sh <secret-name> [region]
# If the secret exists it will be updated; otherwise it will be created.

set -euo pipefail

SECRET_NAME="${1:-}"
AWS_REGION="${2:-eu-central-1}"
BOT_TOKEN="${TELEGRAM_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [[ -z "${SECRET_NAME}" ]]; then
  echo "Usage: $0 <secret-name> [region]"
  exit 1
fi

if [[ -z "${BOT_TOKEN}" || -z "${CHAT_ID}" ]]; then
  echo "TELEGRAM_TOKEN and TELEGRAM_CHAT_ID env vars must be set"
  exit 1
fi

PAYLOAD=$(jq -n \
  --arg token "${BOT_TOKEN}" \
  --arg chat "${CHAT_ID}" \
  '{TELEGRAM_TOKEN:$token, TELEGRAM_CHAT_ID:$chat}')

if aws secretsmanager describe-secret \
    --secret-id "${SECRET_NAME}" \
    --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value \
    --secret-id "${SECRET_NAME}" \
    --region "${AWS_REGION}" \
    --secret-string "${PAYLOAD}"
  echo "Secret ${SECRET_NAME} updated"
else
  aws secretsmanager create-secret \
    --name "${SECRET_NAME}" \
    --region "${AWS_REGION}" \
    --secret-string "${PAYLOAD}"
  echo "Secret ${SECRET_NAME} created"
fi
