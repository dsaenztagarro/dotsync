// `setup` is the one command that creates a config rather than reading one, so
// the rules it has to hold are: never destroy a configuration that already
// exists, and produce a pointer that actually resolves.
package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSetupRefusesToReplaceAnExistingConfig(t *testing.T) {
	dir := t.TempDir()
	cfg := filepath.Join(dir, "dotsync.toml")
	writeFile(t, cfg, "# hand-written, irreplaceable\n")

	if _, err := WriteDefault(cfg); err == nil {
		t.Fatal("expected WriteDefault to refuse an existing config")
	}
	got, err := os.ReadFile(cfg)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(got), "irreplaceable") {
		t.Errorf("the existing config was overwritten: %q", got)
	}
}

func TestTheWrittenPointerResolvesToTheSourcedConfig(t *testing.T) {
	dir := t.TempDir()
	real := filepath.Join(dir, "repo", "dotsync.machine.toml")
	writeFile(t, real, `
[[sync.mappings]]
local = "/local/x"
remote = "/remote/x"
`)
	pointer := filepath.Join(dir, "home", "dotsync.toml")
	written, err := WriteSourcePointer(pointer, real)
	if err != nil {
		t.Fatalf("WriteSourcePointer: %v", err)
	}
	if written != pointer {
		t.Errorf("wrote %q, want %q", written, pointer)
	}

	c := loadOrFail(t, pointer, Push)
	if c.EffectivePath() != real {
		t.Errorf("EffectivePath = %q, want the sourced file %q", c.EffectivePath(), real)
	}
	if ms := c.Mappings(); len(ms) != 1 || ms[0].Src() != "/local/x" {
		t.Errorf("the pointer did not resolve to the sourced mappings: %+v", ms)
	}
}

func TestThePointerRecordsAnAbsolutePathEvenWhenGivenAVariable(t *testing.T) {
	dir := t.TempDir()
	real := filepath.Join(dir, "repo", "dotsync.machine.toml")
	writeFile(t, real, "[[sync.mappings]]\nlocal = \"/l\"\nremote = \"/r\"\n")
	t.Setenv("DOTSYNC_TEST_MIRROR", filepath.Join(dir, "repo"))

	pointer := filepath.Join(dir, "home", "dotsync.toml")
	if _, err := WriteSourcePointer(pointer, "$DOTSYNC_TEST_MIRROR/dotsync.machine.toml"); err != nil {
		t.Fatalf("WriteSourcePointer: %v", err)
	}
	body, err := os.ReadFile(pointer)
	if err != nil {
		t.Fatal(err)
	}
	// A run with no shell profile has no mirror variables, so the variable must
	// not survive into the file.
	if strings.Contains(string(body), "$DOTSYNC_TEST_MIRROR") {
		t.Errorf("the pointer kept an unexpanded variable: %q", body)
	}
	if !strings.Contains(string(body), real) {
		t.Errorf("the pointer does not name %q: %q", real, body)
	}
}

func TestAPointerAtAMissingConfigIsRefused(t *testing.T) {
	dir := t.TempDir()
	pointer := filepath.Join(dir, "dotsync.toml")
	if _, err := WriteSourcePointer(pointer, filepath.Join(dir, "nope.toml")); err == nil {
		t.Fatal("expected a pointer at a nonexistent config to be refused")
	}
	if _, err := os.Stat(pointer); err == nil {
		t.Error("a refused pointer must not leave a file behind")
	}
}
