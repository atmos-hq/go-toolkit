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

This provides targets: `lint`, `lint-fix`, `test`, `test-integration`, `test-coverage`, `build`, `build-dev`, `vet`, `generate`, `docker-build`, `all`, `check`.

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
- **forbidigo** blocks `slog.Default()` — inject the logger via constructor / `WithLogger` Option instead. Exempt sites must carry `//nolint:forbidigo` with a one-line reason.
- **Generated code** excluded via `generated: lax` + explicit path patterns for `*.pb.go`, `*.connect.go`, `sqlc/`, `gen/`
- **Test files** get relaxed rules: errcheck, gosec, bodyclose, funlen, etc.
- **contextcheck** enabled despite false-positive warnings — critical for gRPC/ConnectRPC context propagation
- **containedctx** enabled — storing context in structs is an anti-pattern in our services
- **sloglint** enforces contextual logging (`context: scope`) and no global loggers
- **spancheck** validates OpenTelemetry span usage

## Workspace Conventions (canonical)

Per-repo `CLAUDE.md` files reference this section. When they diverge, this file wins — update both.

### Constructor — use-case Services use functional options

Use cases (`internal/usecase/*/service.go` in auth-service, billing-service) follow gRPC/k8s/OTel-SDK style:

```go
type Option func(*Service)

func WithLogger(log *slog.Logger) Option { return func(s *Service) { s.log = log } }
func WithMetrics(m Metrics) Option       { return func(s *Service) { s.metrics = m } }

func NewService(req1 Dep1, req2 Dep2, opts ...Option) *Service {
    if req1 == nil { panic("<pkg>: req1 is required") }
    if req2 == nil { panic("<pkg>: req2 is required") }
    s := &Service{req1: req1, req2: req2, log: slog.Default()} //nolint:forbidigo // safe default; callers override via WithLogger Option
    for _, opt := range opts { opt(s) }
    return s
}
```

Rules:
- Required deps positional; optional deps via `Option`.
- `Option` lives in the same package as its `Service` (each package owns its `WithXxx` factories — no cross-package option types).
- Panic format is `"<pkg>: <field> is required"` (matches across all services).

### Constructor — gateway handlers use positional args

`gateway/internal/infrastructure/connect/*_handler.go` differ deliberately: 2–3 stable deps, shared package, `WithLogger` would collide across handler types. Positional args, same panic format.

### Logger

- Constructor signature: required `log *slog.Logger` for handlers, or `WithLogger(l)` Option for services.
- **No `slog.Default()` in service or handler code.** The forbidigo linter enforces this; the only legitimate exemptions are (a) the safe-default fallback inside an options-pattern constructor, (b) `logger.FromContext` fallback by contract, (c) the test that asserts that fallback. Each exempt site carries `//nolint:forbidigo // <reason>`.
- Request-path: `*Context` flavour (`InfoContext`, `WarnContext`, `ErrorContext`).
- Boot / async / one-shot: plain flavour (`Info`, `Warn`, `Error`); comment marks the no-ctx site.

### Error

- Wrap with `%w`: `fmt.Errorf("upstream %s: %w", rpc, err)`. Multiple `%w` is allowed (Go ≥1.20) when the error genuinely chains two causes; never use `%s` for an inner error.
- Use cases return `ucerrors.Error` (Code + Category) — the central `ToConnectError(ctx, err)` helper maps Code → `connect.Code` at the handler boundary. Handlers don't build `connect.Error` directly except for handler-level concerns (CSRF Origin mismatch, missing client IP).

### Context

`main()` builds the root ctx with `signal.NotifyContext(ctx, SIGTERM, SIGINT)` so SIGTERM cancels every in-flight RPC. `http.Server.BaseContext` propagates that ctx into every handler. `stop()` runs explicitly (not via `defer`) when paired with `os.Exit` so gocritic's `exitAfterDefer` doesn't fire.

### Pattern summary

| Component | Constructor | Optional deps |
|-----------|-------------|---------------|
| use-case Service (auth/billing) | `NewService(req..., opts ...Option)` | functional options |
| infra handler (gateway connect) | `NewXHandler(pos1, pos2, ...)` | positional only |
| infra adapter (db, mailer, …) | positional | positional only |

## Verification

After any change to this config, verify all consuming services:

```bash
cd ../auth-service && golangci-lint run --config ../go-toolkit/.golangci.yml --timeout 5m ./...
cd ../gateway && golangci-lint run --config ../go-toolkit/.golangci.yml --timeout 5m ./...
```
