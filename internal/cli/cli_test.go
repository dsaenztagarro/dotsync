package cli

import (
	"strings"
	"testing"
)

// A plain `go build` reported 0.0.0-dev at every release tag, because main
// passed its own placeholder in and it always won. These pin the contract
// between the injected version and the compiled-in one.

func TestSetVersionKeepsTheCompiledDefaultWhenNothingIsInjected(t *testing.T) {
	original := version
	t.Cleanup(func() { version = original })

	SetVersion("")
	if version != original {
		t.Errorf("an empty injection changed the version to %q, want %q", version, original)
	}

	SetVersion("1.2.3")
	if version != "1.2.3" {
		t.Errorf("version = %q, want the injected 1.2.3", version)
	}
}

func TestCompiledVersionIsARelease(t *testing.T) {
	if version == "" {
		t.Fatal("no version compiled in")
	}
	if strings.Contains(version, "dev") {
		t.Errorf("version = %q: a built binary must report the release it was built from", version)
	}
}
