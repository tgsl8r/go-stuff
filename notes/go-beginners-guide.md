# Go for Beginners: Projects, Dependencies & Tooling

Nov 5, 2026 · @Toby

## 1. The toolchain

Install Go from [go.dev/dl](https://go.dev/dl) and you get one binary, `go`, that builds, tests, formats, vets and manages dependencies. There is no separate package manager, build tool or test runner to choose. As of this writing the latest major release is Go 1.27 (August 2026); Go ships a major release every February and August, and only the two newest majors get security fixes ([release history](https://go.dev/doc/devel/release)). There is no LTS, so plan to upgrade roughly yearly.

Three things beginners get confused by:

- **GOPATH is legacy.** Before Go 1.11 all code had to live under `$GOPATH/src`. With modules, your project can live anywhere. GOPATH still exists (default `~/go`) but only as a cache: downloaded modules go in `$GOPATH/pkg/mod`, and `go install` puts binaries in `$GOPATH/bin`. Add that `bin` directory to your `PATH`.
- **`go env` is the source of truth.** `go env` prints every setting; `go env -w GOPRIVATE=github.com/myorg/*` persists one. Useful ones: `GOPATH`, `GOBIN`, `GOPROXY`, `GOPRIVATE`, `GOFLAGS`, `GOTOOLCHAIN`, `CGO_ENABLED`, `GOOS`/`GOARCH`.
- **The toolchain can switch itself.** The `go` line in `go.mod` is a minimum required version. If your installed Go is older, it will (by default, `GOTOOLCHAIN=auto`) download and run the right toolchain automatically. An optional `toolchain go1.27.1` line pins a preferred version for the module. Set `GOTOOLCHAIN=local` to forbid downloads.

Cross-compiling is built in: `GOOS=linux GOARCH=arm64 go build ./cmd/server` produces a Linux ARM binary from any machine, and with `CGO_ENABLED=0` it is fully static.

## 2. Modules, packages and layout

A **module** is a versioned unit of code defined by a `go.mod` file; a **package** is a single directory of `.go` files sharing a `package` name. One repo usually holds one module containing many packages.

```bash
mkdir hello && cd hello
go mod init github.com/toby/hello   # module path = where it would be fetched from
```

The module path matters: it is the prefix of every import path in the project, and if you publish, it must match the repo URL so others can `go get` it. For a private or throwaway project any name works (`example.com/hello`).

A typical `go.mod`:

```
module github.com/toby/hello

go 1.26

require github.com/google/uuid v1.6.0

tool honnef.co/go/tools/cmd/staticcheck
```

Rules of the road:

- Every `.go` file in a directory must declare the same package name. The import path is module path + directory, e.g. `github.com/toby/hello/internal/store`.
- `package main` with a `func main()` builds an executable; anything else is a library package.
- Capitalised identifiers (`Store`, `New`) are exported; lowercase ones are private to the package. There are no other visibility keywords.
- Any directory named `internal/` can only be imported by code rooted at its parent. The compiler enforces this, so it is the main tool for hiding implementation details.
- Test files end in `_test.go` and sit beside the code they test.
- `testdata/` directories and names starting with `.` or `_` are ignored by the build.

A common layout that scales from small to medium:

```
hello/
├── go.mod
├── go.sum
├── cmd/
│   ├── server/main.go     # one directory per binary
│   └── migrate/main.go
├── internal/
│   ├── store/store.go
│   └── api/handlers.go
└── README.md
```

Start flat (just `main.go` and `go.mod`) and only add `cmd/` and `internal/` when you have a second binary or code worth hiding. Avoid copying the widely-circulated "golang-standards/project-layout" repo wholesale; it is not an official standard and the Go team's own guidance ([Organizing a Go module](https://go.dev/doc/modules/layout)) is much lighter. Avoid catch-all packages named `utils`, `common` or `helpers`; name packages after what they provide.

## 3. Dependency management

Dependencies are other modules, recorded in `go.mod` and verified by `go.sum`. Both files are committed. There is no lockfile beyond these and no `node_modules`-style local install: modules are cached once per machine in `$GOPATH/pkg/mod`.

```bash
go get github.com/google/uuid           # add or upgrade to latest
go get github.com/google/uuid@v1.5.0    # specific version (also @commit, @branch)
go get -u ./...                          # upgrade all direct + indirect deps (minor/patch)
go get -u=patch ./...                    # patch upgrades only
go get github.com/google/uuid@none      # remove
go mod tidy                              # add missing, drop unused; run this often
go list -m -u all                        # show available upgrades
go mod why -m github.com/some/dep        # why is this in my build?
go mod graph                             # full dependency graph
```

The usual workflow is simply: write the `import`, run `go mod tidy`, commit `go.mod` and `go.sum`.

### How versions are chosen

- Versions are semantic version git tags (`v1.6.0`). Untagged commits get a **pseudo-version** like `v0.0.0-20260301120000-abcdef123456`.
- Go uses **Minimal Version Selection**: for each dependency it picks the lowest version that satisfies every `require` in the graph. Builds are reproducible without a lockfile, and a dependency never silently upgrades just because a newer release exists.
- `// indirect` in `go.mod` marks a dependency you don't import directly but need for the build.
- **Major versions v2+ change the import path.** `github.com/foo/bar/v2` is, to Go, a different module from `github.com/foo/bar`. If you publish a breaking v2, your module path must end in `/v2`. `v0.x` carries no compatibility promise.

### go.sum and the proxy

By default, modules are downloaded via the public proxy (`GOPROXY=https://proxy.golang.org,direct`) and their hashes are checked against the public checksum database (`sum.golang.org`). `go.sum` records those hashes so a tampered download fails the build. Never edit it by hand; `go mod tidy` maintains it, and `go mod verify` checks the cache against it.

**Private repos:** set `go env -w GOPRIVATE=github.com/myorg/*`. That makes Go skip the public proxy and checksum database for those paths and fetch straight from git, using your normal git credentials (SSH keys or a `.netrc`/credential helper). This is the number one stumbling block in company setups and CI.

### Overrides, local development and vendoring

- `replace` in `go.mod` swaps a module for a fork or local path: `replace github.com/foo/bar => ../bar`. It only applies in the main module (it is ignored when your module is a dependency of someone else), so don't commit local-path replaces.
- **Workspaces** (`go work init ./app ./lib`) let you develop several modules side by side without `replace` lines. `go.work` is usually not committed.
- `exclude` and `retract` exist for blocking bad versions (retract is what a library author uses to withdraw their own release).
- `go mod vendor` copies all dependencies into `vendor/`; if that directory exists, builds use it automatically. Use it only if you need air-gapped or fully self-contained builds; most projects rely on the module cache and proxy instead.

### Tool dependencies

Since Go 1.24, developer tools (linters, code generators) can be versioned in `go.mod` alongside code dependencies:

```bash
go get -tool honnef.co/go/tools/cmd/staticcheck@latest
go tool staticcheck ./...
```

This replaces the old `tools.go` blank-import trick and pins everyone, including CI, to the same tool version. Note that the tool's own dependencies join your module graph, which is why some heavyweight tools (golangci-lint in particular) recommend installing their release binary instead.

## 4. Everyday go commands

Most commands take package patterns: `.` is the current package, `./...` is it and everything beneath.

| Command | What it does |
| --- | --- |
| `go run .` | Compile and run the main package in a temp dir |
| `go build ./...` | Compile everything (checks it builds); with one main package, `go build -o bin/server ./cmd/server` writes a binary |
| `go install ./cmd/server` | Build and put the binary in `$GOBIN` / `$GOPATH/bin` |
| `go install golang.org/x/tools/cmd/goimports@latest` | Install a remote tool globally, outside any module |
| `go test ./...` | Run tests; `-v` verbose, `-run TestName` filter, `-race` race detector, `-cover` coverage, `-count=1` bypass cache |
| `go test -bench . -benchmem` | Run benchmarks |
| `go test -fuzz FuzzParse` | Run a fuzz test (built in since 1.18) |
| `go fmt ./...` | Rewrite files in canonical format (wraps `gofmt -l -w`) |
| `go vet ./...` | Built-in static analysis for likely bugs |
| `go fix ./...` | Apply automated rewrites; since 1.26 it modernises code to newer idioms |
| `go doc fmt.Println` | Show documentation in the terminal; `-all` for a whole package |
| `go generate ./...` | Run `//go:generate` commands found in source (mocks, stringers, protobuf) |
| `go tool <name>` | Run a tool declared with `tool` in `go.mod` |
| `go clean -testcache` / `-modcache` | Clear caches when things act strangely |

Two habits that pay off early: always run tests with `-race` in CI (data races are the classic Go concurrency bug and the detector is cheap to turn on), and inject version info at build time rather than hard-coding it: `go build -ldflags "-X main.version=$(git describe --tags)" ./cmd/server`.

## 5. Formatters, linters and static checkers

The practical answer for a new project: format with `gofmt`/`goimports`, run `go vet`, add **golangci-lint** (which bundles staticcheck and dozens of others), run **govulncheck** for security, and use **gopls** in your editor. That covers 95% of what Go teams use.

| Tool | Role | Install / run |
| --- | --- | --- |
| `gofmt` | The one canonical format. Not configurable, and not optional in practice | Ships with Go; `gofmt -l .` lists unformatted files |
| `goimports` | gofmt + adds/removes/groups imports | `go install golang.org/x/tools/cmd/goimports@latest` |
| `gofumpt` | Optional stricter superset of gofmt | Usually enabled via golangci-lint |
| `go vet` | Official checks for real bugs: bad `Printf` args, copied mutexes, unreachable code, struct tag typos | Ships with Go; `go test` runs a subset automatically |
| [staticcheck](https://staticcheck.dev) | The most respected standalone analyser: bugs, simplifications, deprecated APIs, style | `go get -tool honnef.co/go/tools/cmd/staticcheck` |
| [golangci-lint](https://golangci-lint.run) | Meta-linter: runs ~100 linters (incl. staticcheck, errcheck, gosec, revive) in one fast, cached pass, configured by one YAML file | Release binary or `brew install golangci-lint`; then `golangci-lint run` |
| [govulncheck](https://go.dev/doc/security/vuln/) | Checks deps against the Go vulnerability database and only reports vulns in code you actually call | `go install golang.org/x/vuln/cmd/govulncheck@latest`; `govulncheck ./...` |
| gopls | The official language server used by VS Code, Neovim, Zed and others (GoLand has its own engine); shows vet and analysis diagnostics as you type | Installed automatically by the VS Code Go extension |

### golangci-lint in practice

Version 2 (current since 2025) changed the config format: the file must start with `version: "2"`, and formatters live in their own section. A sensible starter `.golangci.yml`:

```yaml
version: "2"

linters:
  default: standard      # errcheck, govet, ineffassign, staticcheck, unused
  enable:
    - bodyclose          # unclosed HTTP response bodies
    - errorlint          # correct use of errors.Is / errors.As / %w
    - gosec              # common security mistakes
    - misspell
    - revive             # configurable style rules (golint successor)
    - unconvert

formatters:
  enable:
    - gofumpt
    - goimports
```

Then `golangci-lint run ./...` to lint, `golangci-lint run --fix` to auto-fix what it can, `golangci-lint fmt` to format, and `golangci-lint linters` to see what is enabled. If you inherit a v1 config, `golangci-lint migrate` converts it. In GitHub Actions, use `golangci/golangci-lint-action` (v7 or later is required for golangci-lint v2) and pin the linter version, because new releases add checks that can break CI unexpectedly.

Tips for beginners: start with the standard set and add linters one at a time rather than enabling everything (`default: all` buries you in style noise). Treat `errcheck` findings seriously: ignoring a returned `error` is the most common real bug it catches. Suppress a specific false positive with `//nolint:lintername // reason` on the line, and always give the reason.

## 6. Putting it together

A minimal, professional setup is a `go.mod`, a `.golangci.yml`, and one place (Makefile or CI script) that runs the same checks locally and in CI:

```makefile
.PHONY: fmt lint test vuln check

fmt:
	golangci-lint fmt

lint:
	go vet ./...
	golangci-lint run ./...

test:
	go test -race -cover ./...

vuln:
	govulncheck ./...

check: lint test vuln
	go mod tidy -diff    # fails if go.mod/go.sum are out of date (Go 1.23+)
```

CI checklist:

- [ ] Use the Go version from `go.mod` (e.g. `actions/setup-go` with `go-version-file: go.mod`) and let it cache the module and build caches
- [ ] `go mod tidy -diff` or `go mod verify` so untidy modules fail fast
- [ ] `golangci-lint run` with a pinned version
- [ ] `go test -race ./...`
- [ ] `govulncheck ./...`
- [ ] Set `GOPRIVATE` and git credentials if you have private modules

### Common beginner pitfalls

- **"package X is not in std" or "no required module provides package".** You imported something not in `go.mod`. Run `go mod tidy`.
- **Running `go get` outside a module** to install a tool. Since Go 1.17, use `go install pkg@version` for global tools, or `go get -tool` inside a module.
- **Import cycles.** Go forbids them outright. They usually mean a package is doing too much; extract the shared types into a smaller package.
- **Upgrading to v2 of a library and nothing changes.** You need to change the import path to `.../v2` everywhere, not just bump the version.
- **Committing a `replace => ../local/path`** that breaks everyone else's build.
- **Unused imports and variables are compile errors**, not warnings. Let `goimports` or your editor manage imports.
- **Over-structuring early.** Deep `pkg/`, `models/`, `services/` trees from other languages fight Go's package model. Fewer, larger packages organised by responsibility work better.

## Sources

- [Go release history](https://go.dev/doc/devel/release) and [Go 1.27 release notes](https://go.dev/doc/go1.27)
- [Go Modules Reference](https://go.dev/ref/mod) and [Organizing a Go module](https://go.dev/doc/modules/layout)
- [golangci-lint documentation](https://golangci-lint.run) and [migrating to v2](https://alexandear.github.io/posts/2025-12-01-upgrade-golangci-lint-v2)
- [Go vulnerability management](https://go.dev/doc/security/vuln/)
- [staticcheck](https://staticcheck.dev)
