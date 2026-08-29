# Go Toolkit

## Commands
`ln -s ../go-toolkit/.golangci.yml .golangci.yml` — each service symlinks the shared config so both `make lint` and a bare `golangci-lint run` (IDE, CI) find it
`include ../go-toolkit/common.mk` — pull in shared Make targets; override `BINARY_NAME`/`DOCKER_IMAGE`/`GO_TEST_FLAGS` etc. *before* this include line, not after

## Unique Patterns
- `depguard` blocks `log` (use `log/slog`), `math/rand` (use `math/rand/v2`), `github.com/pkg/errors`, and `github.com/golang/protobuf`.
- `forbidigo` blocks `slog.Default()` fleet-wide — the only exemptions are the options-pattern constructor's safe-default fallback, `logger.FromContext`'s fallback, and the test asserting that fallback; each needs `//nolint:forbidigo // <reason>`.
- `contextcheck` and `containedctx` are enabled despite noisy false positives — ctx propagation and "no ctx in structs" are enforced harder here than in a typical Go project.
- Generated code (`*.pb.go`, `*.connect.go`, `sqlc/`, `gen/`) is excluded via `generated: lax`; test files get relaxed errcheck/gosec/bodyclose/funlen.

## Hygiene
- After changing `.golangci.yml`, re-run `golangci-lint run --config ../go-toolkit/.golangci.yml` in at least auth-service and gateway before assuming the change is safe fleet-wide — a new/stricter rule can surface violations service-specific code never tripped locally.
