package action

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/dsaenztagarro/dotsync/internal/config"
	"github.com/dsaenztagarro/dotsync/internal/render"
	"github.com/dsaenztagarro/dotsync/internal/render/tui"
)

// These exercise the real pipeline the cockpit sits on: a real config file,
// real trees under t.TempDir(), the real engine, and the real view-model
// builders. Nothing is stubbed — the assertions are about what a user would see
// on screen for that filesystem.

func write(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

// newAction builds an Action over a config file the way cli.run does.
func newAction(t *testing.T, cfgPath string, dir config.Direction, opts Options) *Action {
	t.Helper()
	cfg, err := config.Load(cfgPath, dir)
	if err != nil {
		t.Fatalf("config.Load: %v", err)
	}
	log := render.NewLogger(os.Stdout, false)
	a := New(cfg, dir, log, render.DefaultColors(), render.DefaultIcons(), opts, nil)
	a.mappings = a.cfg.Mappings()
	return a
}

func dataOrFail(t *testing.T, a *Action) tui.Data {
	t.Helper()
	d, err := a.tuiData()
	if err != nil {
		t.Fatalf("tuiData: %v", err)
	}
	return d
}

func findRow(t *testing.T, rows []tui.MappingRow, src string) tui.MappingRow {
	t.Helper()
	for _, r := range rows {
		if r.Src == src {
			return r
		}
	}
	t.Fatalf("no mapping row for %q", src)
	return tui.MappingRow{}
}

// statusFixture writes a config with one filtered mapping, one hooked mapping,
// and one whose destination directory is missing.
func statusFixture(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	write(t, filepath.Join(root, "src/nvim/init.lua"), "vim.opt.number = true\n")
	write(t, filepath.Join(root, "dest/nvim/init.lua"), "vim.opt.number = true\n")
	write(t, filepath.Join(root, "src/ssh/config"), "Host *\n")
	write(t, filepath.Join(root, "dest/ssh/config"), "Host *\n")
	write(t, filepath.Join(root, "src/cabal/config"), "repository hackage\n")

	cfgPath := filepath.Join(root, "dotsync.toml")
	write(t, cfgPath, `
[[push.mappings]]
src = "`+root+`/src/nvim"
dest = "`+root+`/dest/nvim"
force = true
ignore = ["*.swp"]

[[push.mappings]]
src = "`+root+`/src/ssh"
dest = "`+root+`/dest/ssh"
only = ["config"]
hooks = { post_push = ["chmod 600 {files}"] }

[[push.mappings]]
src = "`+root+`/src/cabal/config"
dest = "`+root+`/dest/missing/cabal/config"
`)
	return cfgPath
}

func TestStatusDataDescribesEveryMappingWithoutDiffing(t *testing.T) {
	cfgPath := statusFixture(t)
	a := newAction(t, cfgPath, config.Push, Options{Command: "status", OnlyConfig: true, OnlyMappings: true})
	d := dataOrFail(t, a)

	if d.ShowChanges {
		t.Error("status must not compute a diff")
	}
	if len(d.Changes) != 0 {
		t.Errorf("status produced %d change rows", len(d.Changes))
	}
	if len(d.Mappings) != 3 {
		t.Fatalf("got %d mapping rows, want 3", len(d.Mappings))
	}
	if d.Command != "status" || d.Direction != "push" || d.ConfigPath != cfgPath {
		t.Errorf("header data: command=%q direction=%q config=%q", d.Command, d.Direction, d.ConfigPath)
	}

	nvim := findRow(t, d.Mappings, filepath.Dir(cfgPath)+"/src/nvim")
	if !nvim.Force || !nvim.Ignore || nvim.Only || nvim.Hooks || !nvim.Valid {
		t.Errorf("nvim flags: %+v", nvim)
	}
	if len(nvim.IgnorePatterns) != 1 || nvim.IgnorePatterns[0] != "*.swp" {
		t.Errorf("nvim ignore patterns: %v", nvim.IgnorePatterns)
	}

	ssh := findRow(t, d.Mappings, filepath.Dir(cfgPath)+"/src/ssh")
	if !ssh.Only || !ssh.Hooks {
		t.Errorf("ssh flags: %+v", ssh)
	}
	if len(ssh.HookCommands) != 1 || ssh.HookCommands[0] != "chmod 600 {files}" {
		t.Errorf("ssh hooks: %v", ssh.HookCommands)
	}
}

func TestInvalidMappingCarriesItsReasonAndFix(t *testing.T) {
	cfgPath := statusFixture(t)
	a := newAction(t, cfgPath, config.Push, Options{Command: "status", OnlyConfig: true, OnlyMappings: true})
	d := dataOrFail(t, a)

	if got := d.InvalidCount(); got != 1 {
		t.Fatalf("invalid count = %d, want 1", got)
	}
	cabal := findRow(t, d.Mappings, filepath.Dir(cfgPath)+"/src/cabal/config")
	if cabal.Valid {
		t.Fatal("the mapping with a missing destination directory should be invalid")
	}
	if cabal.InvalidReason != "destination directory does not exist" || cabal.InvalidFix != "--create-dest" {
		t.Errorf("reason=%q fix=%q", cabal.InvalidReason, cabal.InvalidFix)
	}
}

func TestDiffDataGroupsChangesAndCountsThemPerMapping(t *testing.T) {
	root := t.TempDir()
	write(t, filepath.Join(root, "src/app/added.conf"), "new\n")
	write(t, filepath.Join(root, "src/app/changed.conf"), "after\n")
	write(t, filepath.Join(root, "dest/app/changed.conf"), "before\n")
	write(t, filepath.Join(root, "dest/app/stale.conf"), "gone\n")

	cfgPath := filepath.Join(root, "dotsync.toml")
	write(t, cfgPath, `
[[push.mappings]]
src = "`+root+`/src/app"
dest = "`+root+`/dest/app"
force = true
`)
	a := newAction(t, cfgPath, config.Push, Options{Command: "diff"})
	d := dataOrFail(t, a)

	if !d.ShowChanges {
		t.Fatal("diff must compute a diff")
	}
	want := []struct {
		kind tui.Kind
		path string
	}{
		{tui.KindAdded, filepath.Join(root, "dest/app/added.conf")},
		{tui.KindModified, filepath.Join(root, "dest/app/changed.conf")},
		{tui.KindRemoved, filepath.Join(root, "dest/app/stale.conf")},
	}
	if len(d.Changes) != len(want) {
		t.Fatalf("got %d changes, want %d: %+v", len(d.Changes), len(want), d.Changes)
	}
	// Additions first, then modifications, then removals — the classic order.
	for i, w := range want {
		if d.Changes[i].Kind != w.kind || d.Changes[i].Path != w.path {
			t.Errorf("change %d = %+v, want kind %v path %q", i, d.Changes[i], w.kind, w.path)
		}
		if d.Changes[i].Mapping == "" {
			t.Errorf("change %d has no owning mapping", i)
		}
	}

	row := d.Mappings[0]
	if row.Added != 1 || row.Modified != 1 || row.Removed != 1 {
		t.Errorf("per-mapping counts: +%d ~%d -%d", row.Added, row.Modified, row.Removed)
	}
}

func TestConfigTabDataResolvesEnvVarsAndOptions(t *testing.T) {
	root := t.TempDir()
	t.Setenv("DOTSYNC_TEST_ROOT", root)
	write(t, filepath.Join(root, "src/file.conf"), "x\n")
	write(t, filepath.Join(root, "dest/file.conf"), "x\n")

	cfgPath := filepath.Join(root, "dotsync.toml")
	write(t, cfgPath, `
[[push.mappings]]
src = "$DOTSYNC_TEST_ROOT/src"
dest = "$DOTSYNC_TEST_ROOT/dest"
`)
	a := newAction(t, cfgPath, config.Push, Options{Command: "status", OnlyConfig: true, OnlyMappings: true, ForceHooks: true})
	d := dataOrFail(t, a)

	if len(d.EnvVars) != 1 || d.EnvVars[0].Key != "$DOTSYNC_TEST_ROOT" || d.EnvVars[0].Value != root {
		t.Errorf("env rows = %+v, want $DOTSYNC_TEST_ROOT = %q", d.EnvVars, root)
	}
	opts := map[string]string{}
	for _, kv := range d.Options {
		opts[kv.Key] = kv.Value
	}
	if opts["apply"] != "FALSE" || opts["force hooks"] != "TRUE" || opts["config"] != cfgPath {
		t.Errorf("option rows = %+v", d.Options)
	}
	// The row keeps the written form for display and the resolved one for detail.
	if d.Mappings[0].Src != "$DOTSYNC_TEST_ROOT/src" {
		t.Errorf("row lost the written path: %q", d.Mappings[0].Src)
	}
	if d.Mappings[0].RealSrc != filepath.Join(root, "src") {
		t.Errorf("row lost the resolved path: %q", d.Mappings[0].RealSrc)
	}
}

func TestCreateDestNoticesTheDirectoriesItCreated(t *testing.T) {
	root := t.TempDir()
	write(t, filepath.Join(root, "src/app/file.conf"), "x\n")

	cfgPath := filepath.Join(root, "dotsync.toml")
	write(t, cfgPath, `
[[push.mappings]]
src = "`+root+`/src/app"
dest = "`+root+`/dest/app"
`)
	a := newAction(t, cfgPath, config.Push, Options{Command: "diff", CreateDest: true})
	d := dataOrFail(t, a)

	if len(d.Notices) != 1 {
		t.Fatalf("notices = %v, want one created destination", d.Notices)
	}
	if _, err := os.Stat(filepath.Join(root, "dest/app")); err != nil {
		t.Errorf("destination was not created: %v", err)
	}
	if !d.Mappings[0].Valid {
		t.Error("the mapping should be valid once its destination exists")
	}
}

// The cockpit and the classic renderer must agree about a config that ships
// itself: the same condition, surfaced in both, is the whole point of building
// the detection in the config layer rather than in one renderer.
func TestCockpitNoticesAConfigTheRunWouldOverwrite(t *testing.T) {
	root := t.TempDir()
	write(t, filepath.Join(root, "repo/note.md"), "from the repo\n")
	write(t, filepath.Join(root, "local/note.md"), "local\n")

	// A pull whose destination directory holds the config that planned it.
	cfgPath := filepath.Join(root, "local", "dotsync.toml")
	write(t, cfgPath, `
[[sync.mappings]]
local  = "`+root+`/local"
remote = "`+root+`/repo"
`)
	a := newAction(t, cfgPath, config.Pull, Options{Command: "pull"})
	d := dataOrFail(t, a)

	var found string
	for _, n := range d.Notices {
		if strings.Contains(n, cfgPath) {
			found = n
		}
	}
	if found == "" {
		t.Fatalf("expected a notice naming %q, got %v", cfgPath, d.Notices)
	}
	if !strings.Contains(found, "overwritten") {
		t.Errorf("a config on the destination side is overwritten; notice said %q", found)
	}
}

func TestCockpitHeaderNamesTheSourcedConfigNotThePointer(t *testing.T) {
	root := t.TempDir()
	write(t, filepath.Join(root, "repo/note.md"), "from the repo\n")
	write(t, filepath.Join(root, "local/note.md"), "local\n")

	real := filepath.Join(root, "repo", "dotsync.machine.toml")
	write(t, real, `
[[sync.mappings]]
local  = "`+root+`/local"
remote = "`+root+`/repo"
ignore = ["dotsync.machine.toml"]
`)
	pointer := filepath.Join(root, "home", "dotsync.toml")
	write(t, pointer, "source = \""+real+"\"\n")

	a := newAction(t, pointer, config.Pull, Options{Command: "pull"})
	d := dataOrFail(t, a)
	if d.ConfigPath != real {
		t.Errorf("header shows %q; the pointer is not the file anyone edits, want %q", d.ConfigPath, real)
	}
	for _, n := range d.Notices {
		if strings.Contains(n, "dotsync") && strings.Contains(n, "overwritten") {
			t.Errorf("a sourced config outside the payload needs no warning, got %q", n)
		}
	}
	rows := a.optionRows()
	var sawPointer bool
	for _, r := range rows {
		if r.Key == "pointer" && r.Value == pointer {
			sawPointer = true
		}
	}
	if !sawPointer {
		t.Errorf("the pointer stays visible as its own row, got %+v", rows)
	}
}
