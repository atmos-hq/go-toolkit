# Go Toolkit

## Commands
`just sync` / `just check-sync` — each service holds a real copy of `.golangci.yml`, not a symlink; sync pushes this repo's version out, check-sync fails on drift (go-ci.yml enforces the same invariant)
`just check-consumers` — runs the shared config against every consumer; the only thing that proves a `.golangci.yml` change is safe fleet-wide

## Unique Patterns
- `depguard` blocks `log` (use `log/slog`), `math/rand` (use `math/rand/v2`), `github.com/pkg/errors`, and `github.com/golang/protobuf`.
- `forbidigo` blocks `slog.Default()` fleet-wide — the only exemptions are the options-pattern constructor's safe-default fallback, `logger.FromContext`'s fallback, and the test asserting that fallback; each needs `//nolint:forbidigo // <reason>`.
- `contextcheck` and `containedctx` are enabled despite noisy false positives — ctx propagation and "no ctx in structs" are enforced harder here than in a typical Go project.
- Generated code (`*.pb.go`, `*.connect.go`, `sqlc/`, `gen/`) is excluded via `generated: lax`; test files get relaxed errcheck/gosec/bodyclose/funlen.

## Hygiene
- After changing `.golangci.yml`, re-run `golangci-lint run --config ../go-toolkit/.golangci.yml` in at least auth-service and gateway before assuming the change is safe fleet-wide — a new/stricter rule can surface violations service-specific code never tripped locally.
