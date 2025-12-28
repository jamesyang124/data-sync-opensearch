.PHONY: build test run clean docker-build lint

BINARY_NAME=producer
BUILD_DIR=bin

build:
	@echo "Building $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	@go build -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/producer

test:
	@echo "Running tests..."
	@go test -v ./...

run: build
	@echo "Running $(BINARY_NAME)..."
	@$(BUILD_DIR)/$(BINARY_NAME) serve

clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)

docker-build:
	@echo "Building docker image..."
	@docker build -t producer:latest .

lint:
	@echo "Running linter..."
	@golangci-lint run
