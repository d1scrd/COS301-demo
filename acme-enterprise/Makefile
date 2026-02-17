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
