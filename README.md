# go-toolkit

Shared Go tooling configuration for all Tracyn Go services (`auth-service`, `gateway`, future services).

## Contents

| File | Purpose |
|------|---------|
| `.golangci.yml` | Shared [golangci-lint v2](https://golangci-lint.run/) config based on [maratori/golangci-lint-config](https://github.com/maratori/golangci-lint-config) |
| `common.mk` | Shared Makefile targets (lint, test, build, generate, docker) |

## Setup

### 1. Symlink the lint config

golangci-lint v2 has no native config inheritance. We use a symlink so that both `make lint` and bare `golangci-lint run ./...` (IDE integration, CI) find the config:

```bash
cd ../auth-service
ln -s ../go-toolkit/.golangci.yml .golangci.yml
```

> The symlink should be committed to each service repo.

### 2. Include `common.mk`

Add to your service Makefile:

```makefile
BINARY_NAME := auth-service
DOCKER_IMAGE := tracyn/auth-service

include ../go-toolkit/common.mk
```

This provides targets: `lint`, `lint-fix`, `test`, `test-integration`, `test-e2e`, `test-coverage`, `build`, `vet`, `generate`, `docker-build`, `all`, `check`.

Override defaults before the include:

```makefile
GO_TEST_FLAGS := -v -race -count=1
GOLANGCI_TIMEOUT := 10m
include ../go-toolkit/common.mk
```

Services can define additional targets (migrations, key generation, etc.) alongside the shared ones.

## Enabled Linters

### Error Handling

| Linter | What it catches |
|--------|-----------------|
| errcheck | Unchecked errors |
| errname | Sentinel error naming (`ErrXxx`) |
| errorlint | Error wrapping, `%w` enforcement |
| nilerr | Returning nil after error check |
| nilnesserr | `err != nil` but returns different nil error |
| wrapcheck | Unwrapped errors from external packages |

### Static Analysis

| Linter | What it catches |
|--------|-----------------|
| govet | Suspicious constructs (shadow enabled) |
| staticcheck | Includes gosimple + stylecheck |
| unused | Dead code |
| ineffassign | Useless assignments |
| unconvert | Unnecessary type conversions |
| wastedassign | Wasted assignment statements |

### Security

| Linter | What it catches |
|--------|-----------------|
| gosec | Security problems |

### Context & HTTP (critical for gRPC/ConnectRPC)

| Linter | What it catches |
|--------|-----------------|
| bodyclose | Unclosed HTTP response bodies |
| containedctx | `context.Context` stored in structs |
| contextcheck | Context propagation |
| fatcontext | Nested contexts in loops |
| noctx | HTTP requests without context |

### Code Quality

| Linter | What it catches |
|--------|-----------------|
| revive | Extensible, replaces golint |
| gocritic | Opinionated improvements |
| exhaustive | Non-exhaustive switch/map |
| misspell | Typos in comments and strings |
| prealloc | Slice preallocation hints |

### Complexity & Structure

| Linter | Threshold |
|--------|-----------|
| cyclop | Cyclomatic complexity > 15 |
| gocognit | Cognitive complexity > 20 |
| funlen | > 80 lines or > 50 statements |
| nestif | Nesting complexity > 4 |
| nonamedreturns | Named returns |
| nilnil | Simultaneous nil error + nil value |

### Conventions

| Linter | What it catches |
|--------|-----------------|
| goprintffuncname | Printf func naming |
| gomoddirectives | go.mod hygiene |
| depguard | Blocked packages (see below) |

### SQL & DB

| Linter | What it catches |
|--------|-----------------|
| sqlclosecheck | `sql.Rows` / `sql.Stmt` not closed |
| rowserrcheck | `rows.Err()` not checked (pgx) |

### Testing

| Linter | What it catches |
|--------|-----------------|
| testifylint | Testify best practices |
| tparallel | `t.Parallel()` usage |
| usetesting | Testing package replacements |

### Telemetry

| Linter | What it catches |
|--------|-----------------|
| spancheck | OpenTelemetry span mistakes |
| sloglint | slog consistency (contextual logging, no globals) |

### Protobuf

| Linter | What it catches |
|--------|-----------------|
| protogetter | Proto field getter usage |

### Additional (from golden config)

asciicheck, bidichk, copyloopvar, durationcheck, intrange, nolintlint, perfsprint, predeclared, reassign, recvcheck, usestdlibvars, whitespace, modernize, exptostd, mirror

### Formatters

| Formatter | Setting |
|-----------|---------|
| goimports | Local prefix: `github.com/atmos-hq` |
| golines | Max line length: 120 |

### Deliberately Disabled

| Linter | Reason |
|--------|--------|
| gochecknoglobals | We use package vars for config/metrics |
| gochecknoinits | We use init for RegisterValidation |
| testpackage | Painful retrofit |
| godot / godoclint | Low value |
| mnd | Too aggressive |
| dupl | False positives on handlers/tests |

## Depguard Rules

| Blocked Package | Use Instead |
|-----------------|-------------|
| `log` | `log/slog` |
| `math/rand` | `math/rand/v2` |
| `github.com/pkg/errors` | stdlib `errors` + `fmt.Errorf` with `%w` |
| `github.com/golang/protobuf` | `google.golang.org/protobuf` |
| `github.com/satori/go.uuid` | `github.com/google/uuid` |
| `github.com/gofrs/uuid` | `github.com/gofrs/uuid/v5` |

## Test File Relaxations

These linters are disabled in `_test.go` files: bodyclose, containedctx, contextcheck, errcheck, funlen, gosec, noctx, prealloc, unparam, wrapcheck.

## Verification

After any change to this config, verify all consuming services:

```bash
cd ../auth-service && make lint
cd ../gateway && make lint
```
