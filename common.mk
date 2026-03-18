# go-toolkit/common.mk — Shared Makefile for Tracyn Go services
# Include from service Makefiles: include ../go-toolkit/common.mk

# Load .env if present (dash prefix = no error if missing — CI/prod won't have it)
-include .env
export

# Resolve go-toolkit dir relative to this file
GO_TOOLKIT_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
GOLANGCI_CONFIG := $(GO_TOOLKIT_DIR).golangci.yml
GOLANGCI_TIMEOUT ?= 5m

# Overridable defaults
BINARY_NAME ?= $(notdir $(CURDIR))
DOCKER_IMAGE ?= tracyn/$(BINARY_NAME)
GO_TEST_FLAGS ?= -v -race
GO_BUILD_FLAGS ?=

# ── Lint ──────────────────────────────────────────────────────────────

.PHONY: lint lint-fix

lint:
	golangci-lint run --config $(GOLANGCI_CONFIG) --timeout $(GOLANGCI_TIMEOUT) ./...

lint-fix:
	golangci-lint run --config $(GOLANGCI_CONFIG) --timeout $(GOLANGCI_TIMEOUT) --fix ./...

# ── Test ──────────────────────────────────────────────────────────────

.PHONY: test test-integration test-e2e test-coverage

test:
	go test $(GO_TEST_FLAGS) ./...

test-integration:
	go test $(GO_TEST_FLAGS) -tags=integration ./...

test-e2e:
	go test -v -tags=e2e ./tests/e2e/...

test-coverage:
	go test $(GO_TEST_FLAGS) -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# ── Build ─────────────────────────────────────────────────────────────

.PHONY: build vet

build:
	go build $(GO_BUILD_FLAGS) -o bin/$(BINARY_NAME) ./cmd/$(BINARY_NAME)

vet:
	go vet ./...

# ── Generate ──────────────────────────────────────────────────────────

.PHONY: generate

generate:
	go generate ./...

# ── Docker ────────────────────────────────────────────────────────────

.PHONY: docker-build

docker-build:
	docker build -t $(DOCKER_IMAGE) .

# ── Aggregate ─────────────────────────────────────────────────────────

.PHONY: all check

all: generate lint test build

check: lint test
