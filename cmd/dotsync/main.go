// Command dotsync is the single-binary dotfile synchronizer.
package main

import (
	"os"

	"github.com/dsaenztagarro/dotsync/internal/cli"
)

// version is set at build time via -ldflags "-X main.version=<v>". Empty means
// nothing was injected, in which case the version compiled into internal/cli
// stands — a plain `go build` of a release tag then reports that release.
var version = ""

func main() {
	cli.SetVersion(version)
	if err := cli.Execute(); err != nil {
		cli.Fail(err)
		os.Exit(1)
	}
}
