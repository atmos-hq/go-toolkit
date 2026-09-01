set shell := ["bash", "-euo", "pipefail", "-c"]

export PATH := justfile_directory() / "bin:" + env_var("PATH")

# This repo owns the config every consumer copies, so a mismatch here is the
# one that misleads everybody. Must match go-ci.yml.
golangci_version := "v2.13.2"

# Sibling repos holding a copy of .golangci.yml. The copies are real files,
# not symlinks — `just check-sync` is what keeps them identical.
consumers := "auth-service gateway billing-service shop-service go-foundation tracking-service"

[private]
default:
    @just --list --unsorted

# Install pinned tools into bin/
[group('setup')]
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p bin
    curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
        | sh -s -- -b "$PWD/bin" "{{ golangci_version }}"

[group('setup')]
tools:
    @which golangci-lint

[group('quality')]
lint-config:
    golangci-lint config verify --config .golangci.yml

# Fail if any consumer's copy has drifted from this one
[group('sync')]
check-sync:
    #!/usr/bin/env bash
    set -uo pipefail
    drifted=()
    for repo in {{ consumers }}; do
        target="../$repo/.golangci.yml"
        if [ ! -f "$target" ]; then
            printf '%-18s MISSING\n' "$repo"
            drifted+=("$repo")
        elif cmp -s .golangci.yml "$target"; then
            printf '%-18s identical\n' "$repo"
        else
            printf '%-18s DRIFTED\n' "$repo"
            drifted+=("$repo")
        fi
    done
    if [ ${#drifted[@]} -gt 0 ]; then
        printf '\nout of sync: %s — run `just sync`\n' "${drifted[*]}"
        exit 1
    fi

# Copy this repo's .golangci.yml over every consumer's
[group('sync')]
sync:
    #!/usr/bin/env bash
    set -euo pipefail
    for repo in {{ consumers }}; do
        [ -d "../$repo" ] || continue
        cp .golangci.yml "../$repo/.golangci.yml"
        printf '%-18s updated\n' "$repo"
    done
    echo
    echo "Commit the copy in each repo, then run `just check-consumers`."

# Run the config against every consumer — the only thing that proves a change
# is safe fleet-wide. tracking-service is skipped: it lints via
# --new-from-merge-base against ~256 frozen violations, so a full run there
# fails regardless of this config.
[group('quality')]
check-consumers:
    #!/usr/bin/env bash
    set -uo pipefail
    failed=()
    for repo in {{ consumers }}; do
        [ "$repo" = tracking-service ] && continue
        if [ ! -d "../$repo" ]; then
            printf '%-18s skipped (not checked out)\n' "$repo"
            continue
        fi
        printf '\n─── %s ───\n' "$repo"
        (cd "../$repo" && golangci-lint run --config .golangci.yml --timeout 5m ./...) || failed+=("$repo")
    done
    if [ ${#failed[@]} -gt 0 ]; then
        printf '\nconfig change breaks: %s\n' "${failed[*]}"
        exit 1
    fi

[group('quality')]
verify: lint-config check-sync check-consumers
