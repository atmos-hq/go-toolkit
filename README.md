<img src="https://cdn.tracyn.io/logo/app-icon-192.png" alt="Tracyn" width="56" height="56">

# go-toolkit

Run tasks with [`just`](https://just.systems) — `just` lists them, `just setup` installs the pinned toolchain into `bin/`.

Shared Go tooling configuration for all Tracyn Go services (`auth-service`, `gateway`, future services).

## Contents

| File | Purpose |
|------|---------|
| `.golangci.yml` | Shared [golangci-lint v2](https://golangci-lint.run/) config based on [maratori/golangci-lint-config](https://github.com/maratori/golangci-lint-config) |

## Setup

### 1. Copy the lint config

golangci-lint v2 has no config inheritance, so every repo carries its own
byte-identical copy of `.golangci.yml`:

```bash
just sync          # copies this repo's config into every consumer
just check-sync    # fails if any copy has drifted
```

Commit the copy in each service repo. `go-ci.yml` re-checks it against this
repo's `main` on every run, so a drifted copy fails CI rather than silently
linting under different rules.

### 2. Pin the same linter version

Each service's justfile pins `golangci_version`. It must match the
`golangci-lint-version` default in `atmos-hq/.github` `go-ci.yml`, and this
repo's own pin — otherwise lint passes locally and fails in CI with no diff to
blame.

Each service owns its own justfile; there is no shared task file to include.

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
cd ../auth-service && just lint
cd ../gateway && just lint
```
