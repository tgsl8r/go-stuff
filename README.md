# go-starter

A minimal Go service template with pinned linting, race-tested CI and cross-platform release builds.

New to Go? Read [docs/go-beginners-guide.md](docs/go-beginners-guide.md) first; it explains the modules, commands and tools this template uses.

## 1. Install the tools

You need **Go 1.26+**, **make**, **git** and **curl**. Everything else (golangci-lint, govulncheck) is fetched automatically at pinned versions by the Makefile.

| Platform | Command |
| --- | --- |
| macOS | `brew install go` (make, git and curl come with Xcode Command Line Tools: `xcode-select --install`) |
| Linux | Download the tarball from [go.dev/dl](https://go.dev/dl), then `sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.*.linux-amd64.tar.gz`. Install the rest with your package manager, e.g. `sudo apt install make git curl`. Distro `golang` packages are usually too old. |
| Windows | Use WSL (Ubuntu) and follow the Linux steps. Native Windows works for `go` commands, but the Makefile assumes a Unix shell. |

Then put Go's binaries on your `PATH` and check:

```bash
export PATH="$PATH:/usr/local/go/bin:$(go env GOPATH)/bin"   # add to ~/.bashrc or ~/.zshrc
go version   # go1.26 or newer
```

**Editor:** install the Go extension for VS Code (or configure `gopls` in Neovim/Zed). It installs `gopls`, which gives you completion and shows vet and lint problems as you type. GoLand works out of the box.

## 2. Set up the project

```bash
# 1. Create your repo from this template, then clone it
git clone https://github.com/<you>/<repo>.git && cd <repo>

# 2. Replace the placeholder module path (macOS: use sed -i '')
grep -rl 'github.com/your-org/go-starter' . | xargs sed -i 's#github.com/your-org/go-starter#github.com/<you>/<repo>#g'

# 3. Download the pinned linter and run every check
make tools
make check

# 4. Run it
make run
curl localhost:8080/healthz
```

If you rename the binary, rename `cmd/server` and update `BINARY` in the `Makefile` and in `.github/workflows/build.yml`.

## 3. Commands

Run `make help` to see this list in your terminal.

| Command | What it does |
| --- | --- |
| `make run` | Runs the server on `:8080` (override with `ADDR=:9000 make run`) |
| `make build` | Builds a static binary into `bin/`. Cross-compile with `make build GOOS=linux GOARCH=arm64` |
| `make test` | Runs all tests with the race detector and writes `coverage.out` |
| `make cover` | Opens the coverage report in your browser |
| `make fmt` | Formats code with gofumpt and goimports |
| `make lint` | Runs `go vet` and golangci-lint (config in `.golangci.yml`) |
| `make lint-fix` | Like `lint`, but applies automatic fixes |
| `make vuln` | Checks dependencies for known vulnerabilities with govulncheck |
| `make tidy` | Adds missing and removes unused dependencies in `go.mod`/`go.sum` |
| `make tidy-check` | Fails if `go.mod`/`go.sum` aren't tidy (used in CI) |
| `make check` | Runs everything CI runs: tidy-check, lint, test, vuln |
| `make tools` | Downloads the pinned golangci-lint into `.tools/` |
| `make clean` | Deletes `bin/`, `.tools/` and coverage output |

Plain `go` commands work too: `go test ./...`, `go run ./cmd/server`, `go get <module>@latest`.

## 4. Workflows

**`ci.yml`** runs on every push to `main` and every pull request, as four parallel jobs:

- **Lint:** `go vet` plus golangci-lint.
- **Modules tidy:** `go mod tidy -diff` and `go mod verify`.
- **Test:** race-enabled tests; the coverage total appears in the run summary and `coverage.out` is uploaded.
- **Vulnerability scan:** govulncheck.

**`build.yml`** produces binaries for linux and macOS (amd64, arm64) and windows/amd64:

- **Push to `main`:** builds the binaries and attaches them to the workflow run as downloadable artifacts.
- **Push a `v*` tag:** re-runs all of `ci.yml`, builds the binaries, then publishes a GitHub Release with the archives and a `checksums.txt`. Tags containing `-` (e.g. `v0.2.0-rc.1`) become prereleases.

To cut a release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

**`dependabot.yml`** opens weekly grouped PRs for Go module and GitHub Actions updates.

## Layout

```text
cmd/server/         main package: flags, wiring, graceful shutdown
internal/api/       HTTP handlers and tests
internal/version/   build metadata injected via -ldflags
.golangci.yml       linter and formatter config (golangci-lint v2)
docs/               beginner's guide to Go projects, dependencies and tooling
Makefile            entry point for local work and CI
.github/            CI, build/release workflows, Dependabot
```

## Notes

- **Tool versions** are pinned in the `Makefile` (`GOLANGCI_LINT_VERSION`, `GOVULNCHECK_VERSION`). The golangci-lint version is repeated in `ci.yml`; bump both together.
- **Private dependencies:** run `go env -w GOPRIVATE=github.com/<org>/*` locally. In CI, set the same `GOPRIVATE` env var and give git a token for those repos.
- **No `go.sum` yet:** the template has no third-party dependencies. `go mod tidy` creates it when you add one.
