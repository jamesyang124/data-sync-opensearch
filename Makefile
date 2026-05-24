COMPOSE ?= docker compose

.PHONY: provision up down restart logs ps clean start stop health reset inspect-schema inspect-data load-data start-opensearch stop-opensearch restart-opensearch status-opensearch create-indices load-demo-data run-demo-queries check-index-stats check-query-performance start-kafka stop-kafka status-kafka create-topics scale-cdc-topics start-cdc stop-cdc restart-cdc status-cdc register-connector start-producer stop-producer test-producer build-producer start-ops-console stop-ops-console verify-read-consistency benchmark-sustained benchmark-ramp benchmark-stress

# Provision the complete stack end-to-end: infra + data + CDC + benchmark image + ops console
provision:
	@echo "=== Provisioning full stack ==="
	@echo ""
	@echo "[1/7] Building benchmark image..."
	@docker build -q -t data-sync/benchmark:latest benchmark
	@echo "✓ Benchmark image ready"
	@echo ""
	@echo "[2/7] Starting all services (infra + app + ops)..."
	@CURRENT_CONSUMERS=$$(docker compose ps -q consumer 2>/dev/null | wc -l | tr -d ' '); \
	 CURRENT_CONSUMERS=$${CURRENT_CONSUMERS:-0}; \
	 SCALE=$$([ "$$CURRENT_CONSUMERS" -gt 0 ] && echo "$$CURRENT_CONSUMERS" || echo "1"); \
	 docker compose --profile app --profile ops up -d --scale consumer=$$SCALE
	@echo ""
	@echo "[3/7] Waiting for PostgreSQL..."
	@PG_WAIT=0; \
	 until docker compose exec -T postgres pg_isready -U $${POSTGRES_USER:-app} >/dev/null 2>&1; do \
	   PG_WAIT=$$((PG_WAIT + 1)); \
	   if [ $$PG_WAIT -ge 30 ]; then \
	     echo "✗ PostgreSQL not ready after 60s"; exit 1; \
	   fi; \
	   sleep 2; \
	 done
	@echo "✓ PostgreSQL ready"
	@echo ""
	@echo "[4/7] Waiting for OpenSearch (green)..."
	@MAX_WAIT=30 bash opensearch/scripts/wait-for-health.sh
	@echo ""
	@echo "[5/7] Loading PostgreSQL seed data..."
	@bash postgres/scripts/load-csv-data.sh
	@echo ""
	@echo "[6/7] Creating OpenSearch indices..."
	@bash opensearch/scripts/create-indices.sh
	@echo ""
	@echo "[7/7] Registering Debezium CDC connector..."
	@bash debezium/scripts/register-connector.sh
	@echo ""
	@echo "==========================================="
	@echo "  Stack is ready"
	@echo "==========================================="
	@echo ""
	@echo "  PostgreSQL:            localhost:$${POSTGRES_PORT:-5432}"
	@echo "  Kafka:                 localhost:9092"
	@echo "  Kafka UI:              http://localhost:8081"
	@echo "  Kafbat UI:             http://localhost:8084"
	@echo "  Kafka Connect:         http://localhost:8083"
	@echo "  OpenSearch:            http://localhost:$${OPENSEARCH_PORT:-9200}"
	@echo "  OpenSearch Dashboards: http://localhost:$${DASHBOARDS_PORT:-5601}"
	@echo "  Producer API:          http://localhost:8082"
	@echo "  Ops Console:           http://localhost:$${OPS_CONSOLE_PORT:-8090}"
	@echo ""
	@echo "  Run a benchmark:"
	@echo "    make benchmark-sustained"
	@echo "    make benchmark-ramp"
	@echo "    make benchmark-stress"
	@echo ""

# Default targets
up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down
	docker compose up -d

logs:
	docker compose logs -f --tail=200

ps:
	docker compose ps

clean:
	docker compose down -v

# PostgreSQL-specific targets
start:
	@echo "Starting PostgreSQL database..."
	docker compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 5
	@$(COMPOSE) exec -T postgres pg_isready -U $${POSTGRES_USER:-app} || (echo "PostgreSQL not ready yet, waiting..." && sleep 5)
	@echo "PostgreSQL is ready!"
	@echo ""
	@echo "Loading sample data if needed..."
	@bash postgres/scripts/load-csv-data.sh

load-data:
	@echo "Loading CSVs into PostgreSQL..."
	@bash postgres/scripts/load-csv-data.sh

health:
	@echo "PostgreSQL Health Check:"
	@echo "======================="
	@$(COMPOSE) exec -T postgres pg_isready -U $${POSTGRES_USER:-app} && echo "✓ PostgreSQL is running" || echo "✗ PostgreSQL is not responding"
	@echo ""
	@echo "Database Statistics:"
	@$(COMPOSE) exec -T postgres psql -U $${POSTGRES_USER:-app} -d $${POSTGRES_DB:-app} -c "\
		SELECT \
			schemaname, \
			tablename, \
			pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size \
		FROM pg_tables \
		WHERE schemaname NOT IN ('pg_catalog', 'information_schema') \
		ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;" 2>/dev/null || echo "Database not yet initialized"

reset:
	@echo "⚠️  WARNING: This will drop and recreate the database with fresh sample data!"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		bash postgres/scripts/reset-database.sh; \
	else \
		echo "Reset cancelled."; \
	fi

inspect-schema:
	@bash postgres/scripts/inspect-schema.sh

inspect-data:
	@bash postgres/scripts/inspect-data.sh

stop:
	@echo "Stopping PostgreSQL..."
	docker compose stop postgres

# OpenSearch-specific targets
start-opensearch:
	@echo "Starting OpenSearch..."
	docker compose up -d opensearch opensearch-dashboard
	@bash opensearch/scripts/wait-for-health.sh

stop-opensearch:
	@echo "Stopping OpenSearch..."
	docker compose stop opensearch opensearch-dashboard

restart-opensearch:
	@echo "Restarting OpenSearch..."
	@$(MAKE) stop-opensearch
	@$(MAKE) start-opensearch

status-opensearch:
	@echo "OpenSearch Health:"
	@curl -s http://localhost:$${OPENSEARCH_PORT:-9200}/_cluster/health | jq '.'
	@echo ""
	@echo "Nodes:"
	@curl -s http://localhost:$${OPENSEARCH_PORT:-9200}/_cat/nodes?v
	@echo ""
	@echo "Indices:"
	@curl -s http://localhost:$${OPENSEARCH_PORT:-9200}/_cat/indices?v

create-indices:
	@bash opensearch/scripts/create-indices.sh

load-demo-data:
	@bash opensearch/scripts/load-demo-data.sh

run-demo-queries:
	@bash opensearch/scripts/run-demo-queries.sh

check-index-stats:
	@bash opensearch/scripts/check-index-stats.sh

check-query-performance:
	@bash opensearch/scripts/check-query-performance.sh

# Debezium CDC-specific targets
start-cdc:
	@echo "Starting Debezium CDC services..."
	docker compose up -d kafka kafka-ui connect
	@echo "Waiting for services to be ready..."
	@sleep 10
	@echo "✓ Debezium services started"
	@echo ""
	@echo "Registering PostgreSQL connector..."
	@bash debezium/scripts/register-connector.sh
	@echo ""
	@echo "CDC Services:"
	@echo "  - Kafka Connect: http://localhost:8083"
	@echo "  - Kafka UI: http://localhost:8081"

stop-cdc:
	@echo "Stopping Debezium CDC services..."
	docker compose stop kafka kafka-ui connect

restart-cdc:
	@echo "Restarting Debezium connector..."
	@bash debezium/scripts/restart-connector.sh

status-cdc:
	@bash debezium/scripts/check-connector-status.sh

register-connector:
	@bash debezium/scripts/register-connector.sh

scale-cdc-topics:
	@bash scripts/scale-cdc-topics.sh

# Kafka-specific targets
start-kafka:
	@echo "Starting Kafka and UI services..."
	docker compose up -d kafka kafka-ui kafbat-ui
	@echo "✓ Kafka started"
	@echo "  Kafka UI:  http://localhost:8081"
	@echo "  Kafbat UI: http://localhost:8084"

stop-kafka:
	@echo "Stopping Kafka and UI services..."
	docker compose stop kafka kafka-ui kafbat-ui

status-kafka:
	@echo "Kafka topics:"
	@docker compose exec -T kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null || echo "✗ Kafka not running"

# Benchmark shortcut targets (image must be built; run 'make provision' first)
benchmark-sustained:
	@docker compose --profile benchmark run --rm -e BENCHMARK_SCENARIO=sustained benchmark

benchmark-ramp:
	@docker compose --profile benchmark run --rm -e BENCHMARK_SCENARIO=ramp-up benchmark

benchmark-stress:
	@docker compose --profile benchmark run --rm -e BENCHMARK_SCENARIO=stress benchmark

# Kafka validation targets (Feature 003)
test-kafka-performance:
	@echo "Running Kafka performance benchmarks..."
	@echo "======================================="
	@bash kafka/tests/test-all-performance.sh

test-kafka-delivery:
	@echo "Running Kafka delivery guarantee tests..."
	@echo "========================================="
	@bash kafka/tests/test-all-delivery.sh

kafka-reports:
	@echo "Generating Kafka test reports..."
	@echo "================================="
	@bash kafka/tests/generate-reports.sh

test-kafka:
	@echo "Running all Kafka validation tests..."
	@echo "====================================="
	@$(MAKE) test-kafka-performance
	@echo ""
	@$(MAKE) test-kafka-delivery
	@echo ""
	@$(MAKE) kafka-reports

# Producer targets (Feature 006)
start-producer:
	@echo "Starting Producer Service..."
	docker compose up -d producer

stop-producer:
	@echo "Stopping Producer Service..."
	docker compose stop producer

build-producer:
	@echo "Building Producer Service..."
	@cd producer && make build
	@echo "Building Producer Docker Image..."
	@cd producer && make docker-build

test-producer:
	@echo "Running Producer Tests..."
	@cd producer && make test

# Ops console targets
start-ops-console:
	@echo "Starting Ops Console..."
	docker compose --profile ops up -d ops-console
	@echo "Ops Console: http://localhost:$${OPS_CONSOLE_PORT:-8090}"

stop-ops-console:
	@echo "Stopping Ops Console..."
	docker compose --profile ops stop ops-console

verify-read-consistency:
	@bash scripts/verify-read-consistency.sh
