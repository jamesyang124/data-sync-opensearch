.PHONY: build test run docker-build docker-run clean

# Build the consumer binary
build:
	@echo "Building consumer..."
	go build -o bin/consumer ./cmd/consumer

# Run unit tests
test:
	@echo "Running tests..."
	go test -v ./...

# Run unit tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# Run the consumer locally
run:
	@echo "Running consumer..."
	go run ./cmd/consumer

# Build Docker image
docker-build:
	@echo "Building Docker image..."
	docker build -t consumer:latest .

# Run Docker container
docker-run:
	@echo "Running Docker container..."
	docker run --rm --name consumer \
		--network data-sync-opensearch_default \
		-e KAFKA_BROKERS=kafka:9092 \
		-e OPENSEARCH_URL=http://opensearch:9200 \
		-e CONSUMER_GROUP=cdc-consumer-group \
		consumer:latest

# Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -rf bin/
	rm -f coverage.out coverage.html

# Download dependencies
deps:
	@echo "Downloading dependencies..."
	go mod download
	go mod tidy
