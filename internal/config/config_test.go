package config

import (
	"os"
	"path/filepath"
	"testing"
)

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func loadOrFail(t *testing.T, path string, dir Direction) *Config {
	t.Helper()
	c, err := Load(path, dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	return c
}

func TestSectionMappings(t *testing.T) {
	dir := t.TempDir()
	cfg := filepath.Join(dir, "dotsync.toml")
	writeFile(t, cfg, `
[[pull.mappings]]
src = "/remote/nvim"
dest = "/local/nvim"
`)
	ms := loadOrFail(t, cfg, Pull).Mappings()
	if len(ms) != 1 {
		t.Fatalf("expected 1 mapping, got %d", len(ms))
	}
	if ms[0].Src() != "/remote/nvim" || ms[0].Dest() != "/local/nvim" {
		t.Errorf("got src=%q dest=%q", ms[0].Src(), ms[0].Dest())
	}
}

func TestSyncExplicitOrientation(t *testing.T) {
	dir := t.TempDir()
	cfg := filepath.Join(dir, "dotsync.toml")
	writeFile(t, cfg, `
[[sync.mappings]]
local = "/local/x"
remote = "/remote/x"
`)
	push := loadOrFail(t, cfg, Push).Mappings()
	if push[0].Src() != "/local/x" || push[0].Dest() != "/remote/x" {
		t.Errorf("push: src=%q dest=%q", push[0].Src(), push[0].Dest())
	}
	pull := loadOrFail(t, cfg, Pull).Mappings()
	if pull[0].Src() != "/remote/x" || pull[0].Dest() != "/local/x" {
		t.Errorf("pull: src=%q dest=%q", pull[0].Src(), pull[0].Dest())
	}
}

func TestShorthandWithPath(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", "/cfg")
	t.Setenv("XDG_CONFIG_HOME_MIRROR", "/mir")
	dir := t.TempDir()
	cfg := filepath.Join(dir, "dotsync.toml")
	writeFile(t, cfg, `
[[sync.xdg_config]]
path = "nvim"
force = true
`)
	ms := loadOrFail(t, cfg, Pull).Mappings()
	if len(ms) != 1 {
		t.Fatalf("expected 1 mapping, got %d", len(ms))
	}
	m := ms[0]
	if m.Src() != "/mir/nvim" || m.Dest() != "/cfg/nvim" {
		t.Errorf("got src=%q dest=%q", m.Src(), m.Dest())
	}
	if !m.Force() {
		t.Error("force should be true")
	}
	if m.SyncType() != "xdg_config" || m.ManifestKey() != "xdg_config--nvim" {
		t.Errorf("sync_type=%q manifest_key=%q", m.SyncType(), m.ManifestKey())
	}
}

func TestShorthandOnlyAndOrder(t *testing.T) {
	t.Setenv("HOME", "/home/u")
	t.Setenv("HOME_MIRROR", "/home/mir")
	t.Setenv("XDG_BIN_HOME", "/bin")
	t.Setenv("XDG_BIN_HOME_MIRROR", "/binmir")
	dir := t.TempDir()
	cfg := filepath.Join(dir, "dotsync.toml")
	// xdg_bin declared before home in the file, but shorthand order is
	// home, ..., xdg_bin — so home must come first in the result.
	writeFile(t, cfg, `
[[sync.xdg_bin]]
only = ["script.sh"]

[[sync.home]]
path = ".zshenv"
`)
	ms := loadOrFail(t, cfg, Push).Mappings()
	if len(ms) != 2 {
		t.Fatalf("expected 2 mappings, got %d", len(ms))
	}
	if ms[0].SyncType() != "home" || ms[1].SyncType() != "xdg_bin" {
		t.Errorf("shorthand order wrong: %q, %q", ms[0].SyncType(), ms[1].SyncType())
	}
	if !ms[1].HasInclusions() {
		t.Error("xdg_bin should carry the only filter")
	}
}

func TestIncludeDeepMerge(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "base.toml"), `
[[sync.mappings]]
local = "/a"
remote = "/b"
`)
	cfg := filepath.Join(dir, "dotsync.toml")
	writeFile(t, cfg, `
include = "base.toml"

[[sync.mappings]]
local = "/c"
remote = "/d"
`)
	ms := loadOrFail(t, cfg, Push).Mappings()
	if len(ms) != 2 {
		t.Fatalf("arrays should concatenate: got %d mappings", len(ms))
	}
	if ms[0].Src() != "/a" || ms[1].Src() != "/c" {
		t.Errorf("base entries should precede overlay: %q, %q", ms[0].Src(), ms[1].Src())
	}
}

func TestSourceIndirection(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "real.toml"), `
[[sync.mappings]]
local = "/x"
remote = "/y"
`)
	cfg := filepath.Join(dir, "dotsync.toml")
	writeFile(t, cfg, `source = "`+filepath.Join(dir, "real.toml")+`"`)
	ms := loadOrFail(t, cfg, Pull).Mappings()
	if len(ms) != 1 || ms[0].Src() != "/y" || ms[0].Dest() != "/x" {
		t.Errorf("source config not resolved: %+v", ms)
	}
}

func TestValidationErrors(t *testing.T) {
	dir := t.TempDir()

	cases := []struct {
		name    string
		content string
		loadDir Direction
	}{
		{"empty", "", Pull},
		{"missing src/dest", "[[pull.mappings]]\ndest = \"/x\"\n", Pull},
		{"bad section hook key", "[[pull.mappings]]\nsrc=\"/a\"\ndest=\"/b\"\n[pull.mappings.hooks]\npost_push = [\"x\"]\n", Pull},
		{"sync as array", "[[sync]]\nlocal=\"/a\"\n", Push},
		{"sync explicit missing remote", "[[sync.mappings]]\nlocal = \"/a\"\n", Push},
		{"bad sync hook key", "[[sync.mappings]]\nlocal=\"/a\"\nremote=\"/b\"\n[sync.mappings.hooks]\nbogus=[\"x\"]\n", Push},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			cfg := filepath.Join(dir, tc.name+".toml")
			writeFile(t, cfg, tc.content)
			if _, err := Load(cfg, tc.loadDir); err == nil {
				t.Errorf("expected error for %s", tc.name)
			}
		})
	}
}

func TestChainedIncludeRejected(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "mid.toml"), "include = \"base.toml\"\n")
	writeFile(t, filepath.Join(dir, "base.toml"), "[[sync.mappings]]\nlocal=\"/a\"\nremote=\"/b\"\n")
	cfg := filepath.Join(dir, "dotsync.toml")
	writeFile(t, cfg, "include = \"mid.toml\"\n")
	if _, err := Load(cfg, Push); err == nil {
		t.Error("chained include should be rejected")
	}
}

func TestSourceCannotCombineKeys(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "real.toml"), "[[sync.mappings]]\nlocal=\"/a\"\nremote=\"/b\"\n")
	cfg := filepath.Join(dir, "dotsync.toml")
	writeFile(t, cfg, "source = \""+filepath.Join(dir, "real.toml")+"\"\n[[pull.mappings]]\nsrc=\"/a\"\ndest=\"/b\"\n")
	if _, err := Load(cfg, Pull); err == nil {
		t.Error("source combined with other keys should be rejected")
	}
}

func TestMissingConfigFile(t *testing.T) {
	_, err := Load(filepath.Join(t.TempDir(), "nope.toml"), Pull)
	if err == nil {
		t.Fatal("expected error for missing config")
	}
}
