#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"
SERVICE="${2:-all}"

if [[ ! -f "infra/environments/${ENVIRONMENT}.env" ]]; then
  echo "Unknown environment: $ENVIRONMENT"
  exit 1
fi

# shellcheck disable=SC1090
source "infra/environments/${ENVIRONMENT}.env"

deploy_one () {
  local svc="$1"
  echo "----"
  echo "[DEPLOY] env=$ENVIRONMENT service=$svc"
  echo "Using URL: $BASE_URL"
  echo "Mock: helm upgrade / kubectl set image / ecs deploy"
  echo "Mock: healthcheck GET $BASE_URL/$svc/health"
  echo "[DEPLOY] $svc deployed ✅"
}

if [[ "$SERVICE" == "all" ]]; then
  deploy_one "auth"
  deploy_one "payments"
else
  deploy_one "$SERVICE"
fi
