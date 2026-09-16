// Resolution is lossy: `source` is replaced by the tree it points at and
// `include` is consumed by the merge. These tests pin the provenance that
// survives it, because the file a user edits is not always the file dotsync
// was pointed at — under `source` the pointer is the one file nobody edits,
// and the self-reference diagnostic has to check all three.
package config

import (
	"path/filepath"
	"testing"
)

func TestAPlainConfigIsItsOwnProvenance(t *testing.T) {
	dir := t.TempDir()
	cfg := filepath.Join(dir, "dotsync.toml")
	writeFile(t, cfg, `
[[sync.mappings]]
local = "/local/x"
remote = "/remote/x"
`)
	p := loadOrFail(t, cfg, Push).Provenance()
	if p.HostPath != cfg {
		t.Errorf("HostPath = %q, want %q", p.HostPath, cfg)
	}
	if p.SourcePath != "" || p.IncludePath != "" {
		t.Errorf("expected no source/include, got %+v", p)
	}
	if got := p.Files(); len(got) != 1 {
		t.Errorf("Files() = %v, want just the host config", got)
	}
}

func TestSourceProvenanceNamesBothThePointerAndTheSourcedFile(t *testing.T) {
	dir := t.TempDir()
	pointer := filepath.Join(dir, "dotsync.toml")
	real := filepath.Join(dir, "repo", "dotsync.machine.toml")
	writeFile(t, real, `
[[sync.mappings]]
local = "/local/x"
remote = "/remote/x"
`)
	writeFile(t, pointer, "source = \""+real+"\"\n")

	c := loadOrFail(t, pointer, Push)
	p := c.Provenance()
	if p.HostPath != pointer {
		t.Errorf("HostPath = %q, want the pointer %q", p.HostPath, pointer)
	}
	if p.SourcePath != real {
		t.Errorf("SourcePath = %q, want %q", p.SourcePath, real)
	}
	if c.EffectivePath() != real {
		t.Errorf("EffectivePath = %q, want the sourced file %q — the pointer is not what anyone edits", c.EffectivePath(), real)
	}
	if c.Path() != pointer {
		t.Errorf("Path = %q, want the pointer %q", c.Path(), pointer)
	}
}

func TestSourceProvenanceNamesTheIncludeResolvedAgainstTheSourcedFile(t *testing.T) {
	dir := t.TempDir()
	repo := filepath.Join(dir, "repo")
	pointer := filepath.Join(dir, "dotsync.toml")
	real := filepath.Join(repo, "dotsync.machine.toml")
	base := filepath.Join(repo, "dotsync.base.toml")

	writeFile(t, base, `
[[sync.mappings]]
local = "/local/base"
remote = "/remote/base"
`)
	// The include is relative, and resolves against the SOURCED file's
	// directory — this is what lets a repo-resident config include a sibling.
	writeFile(t, real, `
include = "dotsync.base.toml"

[[sync.mappings]]
local = "/local/machine"
remote = "/remote/machine"
`)
	writeFile(t, pointer, "source = \""+real+"\"\n")

	c := loadOrFail(t, pointer, Push)
	p := c.Provenance()
	if p.IncludePath != base {
		t.Errorf("IncludePath = %q, want %q resolved beside the sourced file", p.IncludePath, base)
	}
	want := []string{pointer, real, base}
	got := p.Files()
	if len(got) != len(want) {
		t.Fatalf("Files() = %v, want all three in resolution order %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("Files()[%d] = %q, want %q", i, got[i], want[i])
		}
	}
	// The merge still happened: both mappings survive.
	if n := len(c.Mappings()); n != 2 {
		t.Errorf("got %d mappings, want the base and the overlay merged", n)
	}
}

func TestIncludeProvenanceResolvesAgainstTheHostWhenThereIsNoSource(t *testing.T) {
	dir := t.TempDir()
	cfg := filepath.Join(dir, "dotsync.toml")
	base := filepath.Join(dir, "base.toml")
	writeFile(t, base, `
[[sync.mappings]]
local = "/local/base"
remote = "/remote/base"
`)
	writeFile(t, cfg, `
include = "base.toml"
`)
	c := loadOrFail(t, cfg, Push)
	p := c.Provenance()
	if p.IncludePath != base {
		t.Errorf("IncludePath = %q, want %q", p.IncludePath, base)
	}
	if c.EffectivePath() != cfg {
		t.Errorf("EffectivePath = %q, want the host config %q", c.EffectivePath(), cfg)
	}
}
