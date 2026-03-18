# Go Toolkit

Shared Go tooling configuration for all Tracyn Go services (auth-service, gateway, future services).

## Contents

| File | Purpose |
|------|---------|
| `.golangci.yml` | Shared golangci-lint v2 config (based on [maratori/golangci-lint-config](https://github.com/maratori/golangci-lint-config)) |
| `common.mk` | Shared Makefile targets (lint, test, build, generate, docker) |

## Usage

### Lint Config

Each service symlinks `.golangci.yml` → `../go-toolkit/.golangci.yml` so that both `make lint` (via `common.mk --config` flag) and bare `golangci-lint run ./...` (IDE, CI) find the config.

```bash
cd ../auth-service
ln -s ../go-toolkit/.golangci.yml .golangci.yml
```

### common.mk

Include from any service Makefile:

```makefile
include ../go-toolkit/common.mk
```

This provides targets: `lint`, `lint-fix`, `test`, `test-integration`, `test-e2e`, `test-coverage`, `build`, `vet`, `generate`, `docker-build`, `all`, `check`.

Override defaults before the include:

```makefile
BINARY_NAME := auth-service
DOCKER_IMAGE := tracyn/auth-service
GO_TEST_FLAGS := -v -race -count=1
include ../go-toolkit/common.mk
```

Services can define additional targets (migrations, key generation, etc.) alongside the shared ones.

## Key Decisions

- **depguard** blocks: `log` (use `log/slog`), `math/rand` (use `math/rand/v2`), `github.com/pkg/errors` (use stdlib), `github.com/golang/protobuf` (use `google.golang.org/protobuf`)
- **Generated code** excluded via `generated: lax` + explicit path patterns for `*.pb.go`, `*.connect.go`, `sqlc/`, `gen/`
- **Test files** get relaxed rules: errcheck, gosec, bodyclose, funlen, etc.
- **contextcheck** enabled despite false-positive warnings — critical for gRPC/ConnectRPC context propagation
- **containedctx** enabled — storing context in structs is an anti-pattern in our services
- **sloglint** enforces contextual logging (`context: scope`) and no global loggers
- **spancheck** validates OpenTelemetry span usage

## Verification

After any change to this config, verify all consuming services:

```bash
cd ../auth-service && golangci-lint run --config ../go-toolkit/.golangci.yml --timeout 5m ./...
cd ../gateway && golangci-lint run --config ../go-toolkit/.golangci.yml --timeout 5m ./...
```
