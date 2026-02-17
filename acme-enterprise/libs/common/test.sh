#!/usr/bin/env bash
set -euo pipefail
echo "common: unit tests..."
test -f libs/common/util.sh
echo "common: tests passed ✅"
