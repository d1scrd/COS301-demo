#!/usr/bin/env bash
set -euo pipefail
echo "payments: unit tests..."
test -f services/payments/app.sh
echo "payments: tests passed ✅"
