REPO_ROOT  := $(shell git -C "$(dir $(abspath $(lastword $(MAKEFILE_LIST))))" rev-parse --show-toplevel)
IMAGE      := data-sync/benchmark:latest
COMPOSE    := docker compose -f $(REPO_ROOT)/docker-compose.yml

.PHONY: build stack-up run-sustained run-ramp run-stress clean

## Build the custom k6 image with xk6-faker baked in
build:
	docker build -t $(IMAGE) $(REPO_ROOT)/benchmark

## Start the full pipeline stack (including consumer → OpenSearch indexing).
## run-* targets call this automatically so the entire CDC chain is exercised.
stack-up:
	$(COMPOSE) --profile app up -d
	@echo "Waiting for producer to be healthy..."
	@until $(COMPOSE) exec -T producer wget -qO- http://localhost:8080/health >/dev/null 2>&1; do \
	  sleep 2; \
	done
	@echo "Producer is healthy."

## Run the sustained-load scenario (500 RPS, 120s by default)
run-sustained: stack-up
	$(COMPOSE) --profile benchmark \
	  run --rm \
	  -e BENCHMARK_SCENARIO=sustained \
	  benchmark

## Run the ramp-up scenario (0 → 500 RPS staged)
run-ramp: stack-up
	$(COMPOSE) --profile benchmark \
	  run --rm \
	  -e BENCHMARK_SCENARIO=ramp-up \
	  benchmark

## Run the stress scenario (ramping-vus, finds saturation point)
## Appends breaking_point_rps to stress-summary.json via jq post-processing.
## Requires: jq installed in the host environment.
run-stress: stack-up
	$(COMPOSE) --profile benchmark \
	  run --rm \
	  -e BENCHMARK_SCENARIO=stress \
	  benchmark || exit 0
	@if command -v jq >/dev/null 2>&1; then \
	  BREAKING=$$(jq -r 'select(.metric == "http_req_failed" and .data.tags.type == "Point") | select(.data.value > 0.05) | .data.time' \
	    $(REPO_ROOT)/benchmark/reports/stress-raw.ndjson 2>/dev/null | head -1); \
	  if [ -n "$$BREAKING" ]; then \
	    RPS=$$(jq -r 'select(.metric == "http_reqs" and .data.tags.type == "Point") | .data.value' \
	      $(REPO_ROOT)/benchmark/reports/stress-raw.ndjson 2>/dev/null | tail -1); \
	    jq --argjson rps "$$RPS" '. + {breaking_point_rps: $$rps}' \
	      $(REPO_ROOT)/benchmark/reports/stress-summary.json > /tmp/stress-summary-updated.json && \
	    mv /tmp/stress-summary-updated.json $(REPO_ROOT)/benchmark/reports/stress-summary.json; \
	    echo "Breaking point annotated: $${RPS} RPS"; \
	  else \
	    echo "No threshold breach detected in stress run (system did not saturate)"; \
	  fi; \
	else \
	  echo "WARNING: jq not found — breaking_point_rps annotation skipped. Install jq to enable."; \
	fi

## Delete all generated reports
clean:
	rm -f $(REPO_ROOT)/benchmark/reports/*.json \
	       $(REPO_ROOT)/benchmark/reports/*.ndjson
