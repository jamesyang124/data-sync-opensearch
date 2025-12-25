COMPOSE ?= docker compose

.PHONY: up down restart logs ps clean start stop health reset inspect-schema inspect-data load-data start-cdc stop-cdc restart-cdc status-cdc register-connector test-kafka-performance test-kafka-delivery kafka-reports test-kafka

# Default targets
up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) down
	$(COMPOSE) up -d

logs:
	$(COMPOSE) logs -f --tail=200

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down -v

# PostgreSQL-specific targets
start:
	@echo "Starting PostgreSQL database..."
	$(COMPOSE) up -d postgres
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

stop:
	@echo "Stopping PostgreSQL..."
	$(COMPOSE) stop postgres

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

# Debezium CDC-specific targets
start-cdc:
	@echo "Starting Debezium CDC services..."
	$(COMPOSE) up -d kafka kafka-ui connect
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
	$(COMPOSE) stop kafka kafka-ui connect

restart-cdc:
	@echo "Restarting Debezium connector..."
	@bash debezium/scripts/restart-connector.sh

status-cdc:
	@bash debezium/scripts/check-connector-status.sh

register-connector:
	@bash debezium/scripts/register-connector.sh

# Kafka validation targets (Feature 003)
test-kafka-performance:
	@echo "Running Kafka performance benchmarks..."
	@echo "========================================"
	@bash kafka/tests/test-all-performance.sh

test-kafka-delivery:
	@echo "Running Kafka delivery guarantee tests..."
	@echo "=========================================="
	@bash kafka/tests/test-all-delivery.sh

kafka-reports:
	@echo "Generating Kafka test reports..."
	@echo "================================="
	@bash kafka/tests/generate-reports.sh

test-kafka:
	@echo "Running all Kafka validation tests..."
	@echo "======================================"
	@$(MAKE) test-kafka-performance
	@echo ""
	@$(MAKE) test-kafka-delivery
	@echo ""
	@$(MAKE) kafka-reports
