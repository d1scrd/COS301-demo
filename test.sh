#!/usr/bin/env bash
set -euo pipefail

# Creates a mocked "enterprise" monorepo + GitLab CI/CD pipeline (parallel CI + staged CD)
# Usage:
#   ./make_acme_enterprise.sh [target_dir]
# Example:
#   ./make_acme_enterprise.sh acme-enterprise

ROOT="${1:-acme-enterprise}"

mkdir -p "$ROOT"/{services/{payments,auth},libs/common,infra/environments,.github} 2>/dev/null || true

# ---------- Helpers ----------
write_file() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
'"$@"'
EOF
}

# ---------- Services: payments ----------
cat > "$ROOT/services/payments/app.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "payments: starting..."
echo "payments: OK"
EOF

cat > "$ROOT/services/payments/test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "payments: unit tests..."
test -f services/payments/app.sh
echo "payments: tests passed ✅"
EOF

cat > "$ROOT/services/payments/Dockerfile" <<'EOF'
# Mock Dockerfile (not actually built in the pipeline, just to look enterprise-y)
FROM alpine:3.20
COPY . /app
WORKDIR /app
CMD ["sh", "-c", "echo payments container running"]
EOF

# ---------- Services: auth ----------
cat > "$ROOT/services/auth/app.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "auth: starting..."
echo "auth: OK"
EOF

cat > "$ROOT/services/auth/test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "auth: unit tests..."
test -f services/auth/app.sh
echo "auth: tests passed ✅"
EOF

cat > "$ROOT/services/auth/Dockerfile" <<'EOF'
# Mock Dockerfile (not actually built in the pipeline, just to look enterprise-y)
FROM alpine:3.20
COPY . /app
WORKDIR /app
CMD ["sh", "-c", "echo auth container running"]
EOF

# ---------- Shared lib: common ----------
cat > "$ROOT/libs/common/util.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "common util loaded"
EOF

cat > "$ROOT/libs/common/test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "common: unit tests..."
test -f libs/common/util.sh
echo "common: tests passed ✅"
EOF

# ---------- Infra (mock deploy) ----------
cat > "$ROOT/infra/environments/staging.env" <<'EOF'
BASE_URL="https://staging.acme.local"
EOF

cat > "$ROOT/infra/environments/production.env" <<'EOF'
BASE_URL="https://prod.acme.local"
EOF

cat > "$ROOT/infra/deploy.sh" <<'EOF'
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
EOF

# ---------- GitLab CI/CD pipeline ----------
cat > "$ROOT/.gitlab-ci.yml" <<'EOF'
stages:
  - validate
  - test
  - integration
  - build
  - deploy

default:
  image: alpine:3.20
  before_script:
    - apk add --no-cache bash coreutils

# -------------------------
# CI: Validate (parallel)
# -------------------------
lint:
  stage: validate
  script:
    - echo "Linting (mock)..."
    - test -f services/payments/app.sh
    - test -f services/auth/app.sh
    - test -f libs/common/util.sh
    - echo "lint ✅"

# -------------------------
# CI: Unit tests (parallel)
# -------------------------
unit:common:
  stage: test
  script:
    - bash libs/common/test.sh

unit:auth:
  stage: test
  script:
    - bash services/auth/test.sh

unit:payments:
  stage: test
  script:
    - bash services/payments/test.sh

# -------------------------
# CI: Integration gate
# -------------------------
integration:
  stage: integration
  needs: ["lint", "unit:common", "unit:auth", "unit:payments"]
  script:
    - echo "Running integration (mock)..."
    - bash services/auth/app.sh
    - bash services/payments/app.sh
    - echo "integration ✅"

# -------------------------
# Build artifacts (mock images)
# -------------------------
build:
  stage: build
  needs: ["integration"]
  script:
    - echo "Building artifacts..."
    - mkdir -p dist
    - tar -czf dist/auth.tar.gz services/auth libs/common
    - tar -czf dist/payments.tar.gz services/payments libs/common
    - echo "Artifacts created:"
    - ls -lah dist
  artifacts:
    name: "dist-$CI_COMMIT_SHORT_SHA"
    paths:
      - dist/*.tar.gz
    expire_in: 1 week

# -------------------------
# CD: Deploy to staging automatically (only main)
# -------------------------
deploy:staging:
  stage: deploy
  needs: ["build"]
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
  script:
    - bash infra/deploy.sh staging all
  environment:
    name: staging

# -------------------------
# CD: Deploy to production manually (only tags)
# -------------------------
deploy:production:
  stage: deploy
  needs: ["build"]
  rules:
    - if: '$CI_COMMIT_TAG'
  when: manual
  allow_failure: false
  script:
    - bash infra/deploy.sh production all
  environment:
    name: production
EOF

# ---------- Makefile (nice for local demo) ----------
cat > "$ROOT/Makefile" <<'EOF'
.PHONY: lint test unit integration build deploy-staging deploy-prod

lint:
	@echo "Lint (mock)"; \
	test -f services/payments/app.sh && test -f services/auth/app.sh && test -f libs/common/util.sh; \
	echo "lint ✅"

unit:
	@bash libs/common/test.sh
	@bash services/auth/test.sh
	@bash services/payments/test.sh

integration:
	@echo "integration (mock)"; \
	bash services/auth/app.sh; \
	bash services/payments/app.sh; \
	echo "integration ✅"

build:
	@mkdir -p dist
	@tar -czf dist/auth.tar.gz services/auth libs/common
	@tar -czf dist/payments.tar.gz services/payments libs/common
	@ls -lah dist

deploy-staging:
	@bash infra/deploy.sh staging all

deploy-prod:
	@bash infra/deploy.sh production all
EOF

# ---------- Permissions ----------
chmod +x \
  "$ROOT/services/payments/app.sh" \
  "$ROOT/services/payments/test.sh" \
  "$ROOT/services/auth/app.sh" \
  "$ROOT/services/auth/test.sh" \
  "$ROOT/libs/common/util.sh" \
  "$ROOT/libs/common/test.sh" \
  "$ROOT/infra/deploy.sh"

# ---------- Optional: init git repo ----------
if command -v git >/dev/null 2>&1; then
  (
    cd "$ROOT"
    git init -q
    git add .
    git commit -qm "Initial mocked enterprise monorepo with GitLab CI/CD"
    git branch -M main
  )
fi

echo "✅ Created repo scaffold in: $ROOT"
echo "Next steps:"
echo "  1) cd $ROOT"
echo "  2) (Optional) run locally: make lint && make unit && make integration && make build"
echo "  3) Push to GitLab to see parallel CI + staged deploy in pipeline UI"
echo "  4) Demo breakage: edit services/payments/test.sh to fail, commit, push"
