// Command dotsync is the single-binary dotfile synchronizer.
package main

import (
	"os"

	"github.com/dsaenztagarro/dotsync/internal/cli"
)

// version is set at build time via -ldflags "-X main.version=<v>".
var version = "0.0.0-dev"

func main() {
	cli.SetVersion(version)
	if err := cli.Execute(); err != nil {
		cli.Fail(err)
		os.Exit(1)
	}
}
