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

This provides the shared targets (`lint`, `test`, `build`, `generate`, `docker-build`, `all`, `check`, …) — see [`common.mk`](./common.mk) for the full set.

Override defaults before the include:

```makefile
GO_TEST_FLAGS := -v -race -count=1
GOLANGCI_TIMEOUT := 10m
include ../go-toolkit/common.mk
```

Services can define additional targets (migrations, key generation, etc.) alongside the shared ones.

## Enabled Linters

The enabled linter set, tuned complexity thresholds (cyclop, gocognit, funlen, nestif), and formatter settings (goimports local prefix `github.com/atmos-hq`, golines max line length 120) live in [`.golangci.yml`](./.golangci.yml) — read it rather than a hand-maintained mirror that drifts. The non-obvious enable/disable rationale (contextcheck despite its false positives, containedctx, sloglint, spancheck, generated-code exclusion) is captured in [`CLAUDE.md`](./CLAUDE.md) → *Key Decisions*.

One grouping worth calling out: the **Context & HTTP** linters (bodyclose, containedctx, contextcheck, fatcontext, noctx) are enabled specifically because context propagation is critical for gRPC/ConnectRPC.

### Deliberately Disabled

Why each is off (intent — not derivable from the config):

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
