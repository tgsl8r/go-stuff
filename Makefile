# Run `make help` to list targets.

# ---- Project ---------------------------------------------------------------
MODULE  := $(shell go list -m)
BINARY  ?= server
CMD     ?= ./cmd/$(BINARY)
BIN_DIR ?= bin

# Cross-compilation: `make build GOOS=linux GOARCH=arm64`
GOOS   ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)
EXT    := $(if $(filter windows,$(GOOS)),.exe,)
OUT    ?= $(BIN_DIR)/$(BINARY)-$(GOOS)-$(GOARCH)$(EXT)

# ---- Version metadata (injected into internal/version) ---------------------
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT  ?= $(shell git rev-parse HEAD 2>/dev/null || echo unknown)
DATE    ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS := -s -w \
	-X $(MODULE)/internal/version.Version=$(VERSION) \
	-X $(MODULE)/internal/version.Commit=$(COMMIT) \
	-X $(MODULE)/internal/version.Date=$(DATE)

# ---- Tool versions (keep GOLANGCI_LINT_VERSION in sync with .github/workflows/ci.yml)
GOLANGCI_LINT_VERSION ?= v2.15.0
GOVULNCHECK_VERSION   ?= v1.9.0

TOOLS_DIR     := $(CURDIR)/.tools
GOLANGCI_LINT := $(TOOLS_DIR)/golangci-lint-$(GOLANGCI_LINT_VERSION)

.DEFAULT_GOAL := help

## Development

.PHONY: run
run: ## Run the server locally
	go run $(CMD)

.PHONY: build
build: ## Build a static binary for GOOS/GOARCH into bin/
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) \
		go build -trimpath -ldflags "$(LDFLAGS)" -o $(OUT) $(CMD)
	@echo "built $(OUT) ($(VERSION))"

.PHONY: test
test: ## Run tests with the race detector and coverage
	go test -race -covermode=atomic -coverprofile=coverage.out ./...

.PHONY: cover
cover: test ## Open the HTML coverage report
	go tool cover -html=coverage.out

## Code quality

.PHONY: fmt
fmt: $(GOLANGCI_LINT) ## Format code (gofumpt + goimports)
	$(GOLANGCI_LINT) fmt

.PHONY: lint
lint: $(GOLANGCI_LINT) ## Run go vet and golangci-lint
	go vet ./...
	$(GOLANGCI_LINT) run ./...

.PHONY: lint-fix
lint-fix: $(GOLANGCI_LINT) ## Run golangci-lint and apply automatic fixes
	$(GOLANGCI_LINT) run --fix ./...

.PHONY: vuln
vuln: ## Scan dependencies for known vulnerabilities
	go run golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION) ./...

.PHONY: tidy
tidy: ## Add missing and remove unused modules
	go mod tidy

.PHONY: tidy-check
tidy-check: ## Fail if go.mod/go.sum are not tidy
	go mod tidy -diff
	go mod verify

.PHONY: check
check: tidy-check lint test vuln ## Everything CI runs

## Housekeeping

.PHONY: tools
tools: $(GOLANGCI_LINT) ## Install pinned developer tools into .tools/

$(GOLANGCI_LINT):
	@mkdir -p $(TOOLS_DIR)
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
		| sh -s -- -b $(TOOLS_DIR) $(GOLANGCI_LINT_VERSION)
	mv $(TOOLS_DIR)/golangci-lint $@

.PHONY: clean
clean: ## Remove build output, coverage and tools
	rm -rf $(BIN_DIR) $(TOOLS_DIR) coverage.out

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} \
		/^## / { printf "\n\033[1m%s\033[0m\n", substr($$0, 4) } \
		/^[a-zA-Z_-]+:.*## / { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
