FROM golang:1.24-alpine AS builder

WORKDIR /src
COPY go.mod ./
COPY cmd ./cmd
RUN go build -o /out/ops-console ./cmd/ops-console

FROM docker:27-cli

RUN apk add --no-cache docker-cli-compose

WORKDIR /workspace
COPY --from=builder /out/ops-console /usr/local/bin/ops-console
EXPOSE 8090
ENTRYPOINT ["ops-console"]
