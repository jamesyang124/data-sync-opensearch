# Ops Console

Small local web console for operating the Docker Compose data sync pipeline.

## Features

- Links to Kafbat UI, Kafka UI, and OpenSearch Dashboards.
- Status probes for producer, consumer, and OpenSearch.
- Consumer scaling through `docker compose --profile app up -d --scale consumer=N`.
- Benchmark launch with adjustable scenario, target RPS, duration, and consumer replica count.
- Last benchmark status and output tail via `/api/benchmark/last`.

## Run

The Docker Compose service mounts the project root and Docker socket so it can run `docker compose` commands from inside the container.

```bash
docker compose --profile ops up -d ops-console
open http://localhost:8090
```

For Colima or non-standard Docker socket paths, set `DOCKER_SOCKET` in `.env`:

```env
DOCKER_SOCKET=/Users/<you>/.colima/default/docker.sock
```

## Safety

This console is intended for local development only. Mounting the Docker socket gives the container control over the local Docker daemon.
