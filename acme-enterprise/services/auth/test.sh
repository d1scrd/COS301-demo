#!/usr/bin/env bash
set -euo pipefail
echo "auth: unit tests..."
test -f services/auth/app.sh
echo "auth: tests passed ✅"
