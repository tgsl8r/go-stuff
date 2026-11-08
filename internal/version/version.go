// Package version exposes build metadata injected at link time via -ldflags.
package version

// These are overwritten by the Makefile at build time, e.g.
//
//	-X github.com/org/repo/internal/version.Version=v1.2.3
var (
	// Version is the semantic version or `git describe` output.
	Version = "dev"
	// Commit is the full git commit SHA.
	Commit = "unknown"
	// Date is the UTC build timestamp in RFC 3339 format.
	Date = "unknown"
)

// Info is a JSON-friendly snapshot of the build metadata.
type Info struct {
	Version string `json:"version"`
	Commit  string `json:"commit"`
	Date    string `json:"date"`
}

// Get returns the current build metadata.
func Get() Info {
	return Info{Version: Version, Commit: Commit, Date: Date}
}
