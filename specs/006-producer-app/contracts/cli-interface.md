# CLI Interface Contract

**Application**: `producer`
**Version**: 1.0.0

## Global Flags

All commands support these flags:
- `--config <path>`: Path to config file (default: `$HOME/.producer.yaml`)
- `--log-level <level>`: Logging level (debug, info, warn, error). Default: `info`

## Environment Variables

Configuration can be provided via environment variables (prefixed with `PRODUCER_`):
- `PRODUCER_PORT`: HTTP Server port (default: 8080)
- `PRODUCER_METRICS_PORT`: Prometheus metrics port (default: 9090)
- `PRODUCER_DB_HOST`: PostgreSQL host
- `PRODUCER_DB_PORT`: PostgreSQL port (default: 5432)
- `PRODUCER_DB_USER`: Database user
- `PRODUCER_DB_PASSWORD`: Database password
- `PRODUCER_DB_NAME`: Database name
- `PRODUCER_DB_SSLMODE`: SSL mode (disable, require, etc.)

## Commands

### `serve`

Starts the HTTP API server.

**Usage**: `producer serve [flags]`

**Flags**:
- `--port <int>`: Port to listen on (default: 8080)
- `--metrics-port <int>`: Port for metrics (default: 9090)

**Examples**:
```bash
producer serve --port 8080
```

### `version`

Prints application version.

**Usage**: `producer version`

## Metrics Contract (JSON)

The following metrics are exposed at `/metrics` as a JSON object:

```json
{
  "http": {
    "requests_total": 100,
    "requests_2xx": 95,
    "requests_5xx": 5,
    "average_latency_ms": 45.2
  },
  "db": {
    "pool_open_connections": 5,
    "pool_in_use": 2
  },
  "runtime": {
    "uptime_seconds": 120,
    "goroutines": 15
  }
}
```
