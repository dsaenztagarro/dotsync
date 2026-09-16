// These tests pin the diagnostic that warns when a configuration ships itself.
//
// The contract is narrow on purpose. A report means "applying this mapping
// would rewrite a file that produced this configuration", which is why the
// mapping's own `only` and `ignore` filters have to be honoured: a config the
// mapping already excludes is not at risk, and a false positive here fires on
// setups that work fine today. The boundary case matters for the same reason —
// `Mapping.Ignore` deliberately reproduces Ruby's raw prefix check, so a
// containment test built on prefixes alone would report `/a/configs` as
// containing `/a/config`.
//
// Which side the config sits on is part of the contract, not a detail: on the
// destination side the run overwrites the config it was planned from, on the
// source side it copies it out over the far end. Both are worth saying; they
// are not the same sentence.
package config

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/dsaenztagarro/dotsync/internal/model"
)

func mkdirs(t *testing.T, paths ...string) {
	t.Helper()
	for _, p := range paths {
		if err := os.MkdirAll(p, 0o755); err != nil {
			t.Fatal(err)
		}
	}
}

// refsFor runs the detector over one host config path.
func refsFor(t *testing.T, mappings []*model.Mapping, hostPath string) []SelfReference {
	t.Helper()
	return SelfReferences(mappings, Provenance{HostPath: hostPath})
}

func TestDirectoryMappingContainingTheConfigIsReported(t *testing.T) {
	root := t.TempDir()
	local, remote := filepath.Join(root, "local"), filepath.Join(root, "remote")
	mkdirs(t, local, remote)
	cfg := filepath.Join(local, "dotsync.toml")
	writeFile(t, cfg, "")

	m := model.New(model.Attributes{Src: remote, Dest: local})
	refs := refsFor(t, []*model.Mapping{m}, cfg)
	if len(refs) != 1 {
		t.Fatalf("expected the config inside the destination to be reported, got %d refs", len(refs))
	}
	if refs[0].ConfigFile != cfg {
		t.Errorf("reported %q, want %q", refs[0].ConfigFile, cfg)
	}
	if refs[0].Role != Overwritten {
		t.Errorf("a config inside the destination is overwritten, got role %v", refs[0].Role)
	}
}

func TestAConfigOnTheSourceSideIsReportedAsPropagated(t *testing.T) {
	root := t.TempDir()
	local, remote := filepath.Join(root, "local"), filepath.Join(root, "remote")
	mkdirs(t, local, remote)
	cfg := filepath.Join(local, "dotsync.toml")
	writeFile(t, cfg, "")

	// A push: the live config is the source, so the run ships it out and
	// silently replaces whatever the repo held.
	m := model.New(model.Attributes{Src: local, Dest: remote})
	refs := refsFor(t, []*model.Mapping{m}, cfg)
	if len(refs) != 1 {
		t.Fatalf("expected the config inside the source to be reported, got %d refs", len(refs))
	}
	if refs[0].Role != Propagated {
		t.Errorf("a config inside the source is propagated, got role %v", refs[0].Role)
	}
}

func TestAConfigOnNeitherSideIsNotReported(t *testing.T) {
	root := t.TempDir()
	local, remote := filepath.Join(root, "local"), filepath.Join(root, "remote")
	mkdirs(t, local, remote)
	cfg := filepath.Join(root, "elsewhere", "dotsync.toml")
	writeFile(t, cfg, "")

	m := model.New(model.Attributes{Src: local, Dest: remote})
	if refs := refsFor(t, []*model.Mapping{m}, cfg); len(refs) != 0 {
		t.Fatalf("a config outside both sides takes no part in the transfer, got %d refs", len(refs))
	}
}

func TestRenameMappingOntoTheConfigPathIsReported(t *testing.T) {
	root := t.TempDir()
	local, remote := filepath.Join(root, "local"), filepath.Join(root, "remote")
	mkdirs(t, local, remote)
	cfg := filepath.Join(local, "dotsync.toml")
	writeFile(t, cfg, "")
	src := filepath.Join(remote, "dotsync.machine.toml")
	writeFile(t, src, "")

	// The destination IS the config, under a different name in the repo.
	m := model.New(model.Attributes{Src: src, Dest: cfg})
	if refs := refsFor(t, []*model.Mapping{m}, cfg); len(refs) != 1 {
		t.Fatalf("expected a mapping whose destination is the config to be reported, got %d refs", len(refs))
	}
}

func TestAConfigTheMappingIgnoresIsNotReported(t *testing.T) {
	root := t.TempDir()
	local, remote := filepath.Join(root, "local"), filepath.Join(root, "remote")
	mkdirs(t, local, remote)
	cfg := filepath.Join(local, "dotsync.toml")
	writeFile(t, cfg, "")

	m := model.New(model.Attributes{Src: remote, Dest: local, Ignore: []string{"dotsync.toml"}})
	if refs := refsFor(t, []*model.Mapping{m}, cfg); len(refs) != 0 {
		t.Fatalf("an ignored config is not at risk, got %d refs", len(refs))
	}
}

func TestAnOnlyFilterExcludingTheConfigIsNotReported(t *testing.T) {
	root := t.TempDir()
	local, remote := filepath.Join(root, "local"), filepath.Join(root, "remote")
	mkdirs(t, local, remote)
	cfg := filepath.Join(local, "dotsync.toml")
	writeFile(t, cfg, "")

	m := model.New(model.Attributes{Src: remote, Dest: local, Only: []string{"nvim"}})
	if refs := refsFor(t, []*model.Mapping{m}, cfg); len(refs) != 0 {
		t.Fatalf("a config outside the only-filter is not at risk, got %d refs", len(refs))
	}

	// ...and the same mapping whose filter does select it is reported.
	sel := model.New(model.Attributes{Src: remote, Dest: local, Only: []string{"dotsync.toml"}})
	if refs := refsFor(t, []*model.Mapping{sel}, cfg); len(refs) != 1 {
		t.Fatalf("a config selected by the only-filter is at risk, got %d refs", len(refs))
	}
}

func TestTheSourcedFileIsCheckedNotJustThePointer(t *testing.T) {
	root := t.TempDir()
	repo, local := filepath.Join(root, "repo"), filepath.Join(root, "local")
	mkdirs(t, repo, local)
	pointer := filepath.Join(root, "pointer", "dotsync.toml")
	writeFile(t, pointer, "")
	sourced := filepath.Join(repo, "dotsync.machine.toml")
	writeFile(t, sourced, "")

	// The mapping pushes the repo out; the pointer is nowhere near it.
	m := model.New(model.Attributes{Src: local, Dest: repo})
	refs := SelfReferences([]*model.Mapping{m}, Provenance{HostPath: pointer, SourcePath: sourced})
	if len(refs) != 1 {
		t.Fatalf("expected the sourced file to be reported, got %d refs", len(refs))
	}
	if refs[0].ConfigFile != sourced {
		t.Errorf("reported %q, want the sourced file %q", refs[0].ConfigFile, sourced)
	}
}

func TestAPointerOutsideBothSidesIsNotReported(t *testing.T) {
	root := t.TempDir()
	repo, local := filepath.Join(root, "repo"), filepath.Join(root, "local")
	mkdirs(t, repo, local)
	pointer := filepath.Join(root, "pointer", "dotsync.toml")
	writeFile(t, pointer, "")

	m := model.New(model.Attributes{Src: repo, Dest: local})
	if refs := refsFor(t, []*model.Mapping{m}, pointer); len(refs) != 0 {
		t.Fatalf("a pointer outside both sides is not at risk, got %d refs", len(refs))
	}
}

func TestTheIncludedBaseIsCheckedToo(t *testing.T) {
	root := t.TempDir()
	repo, local := filepath.Join(root, "repo"), filepath.Join(root, "local")
	mkdirs(t, repo, local)
	host := filepath.Join(local, "dotsync.toml")
	writeFile(t, host, "")
	base := filepath.Join(repo, "dotsync.base.toml")
	writeFile(t, base, "")

	// The host config sits in the source and the base in the destination, so
	// one mapping puts both at stake, each in its own way.
	m := model.New(model.Attributes{Src: local, Dest: repo})
	refs := SelfReferences([]*model.Mapping{m}, Provenance{HostPath: host, IncludePath: base})
	if len(refs) != 2 {
		t.Fatalf("expected both the host config and the included base, got %+v", refs)
	}
	got := map[string]Role{}
	for _, r := range refs {
		got[r.ConfigFile] = r.Role
	}
	if role, ok := got[base]; !ok || role != Overwritten {
		t.Errorf("the included base is on the destination side: got %v (present=%v)", role, ok)
	}
	if role, ok := got[host]; !ok || role != Propagated {
		t.Errorf("the host config is on the source side: got %v (present=%v)", role, ok)
	}
}

func TestASiblingSharingAPathPrefixIsNotReported(t *testing.T) {
	root := t.TempDir()
	dest := filepath.Join(root, "config")
	sibling := filepath.Join(root, "configs")
	src := filepath.Join(root, "src")
	mkdirs(t, dest, sibling, src)
	cfg := filepath.Join(sibling, "dotsync.toml")
	writeFile(t, cfg, "")

	// dest is "…/config"; the config lives in "…/configs". A prefix test alone
	// would call that containment.
	m := model.New(model.Attributes{Src: src, Dest: dest})
	if refs := refsFor(t, []*model.Mapping{m}, cfg); len(refs) != 0 {
		t.Fatalf("a sibling directory sharing a prefix is not containment, got %d refs", len(refs))
	}
}

func TestAnInvalidMappingIsNeverReported(t *testing.T) {
	root := t.TempDir()
	local := filepath.Join(root, "local")
	mkdirs(t, local)
	cfg := filepath.Join(local, "dotsync.toml")
	writeFile(t, cfg, "")

	// Source does not exist, so the mapping never transfers anything.
	m := model.New(model.Attributes{Src: filepath.Join(root, "missing"), Dest: local})
	if m.Valid() {
		t.Fatal("fixture is wrong: the mapping was expected to be invalid")
	}
	if refs := refsFor(t, []*model.Mapping{m}, cfg); len(refs) != 0 {
		t.Fatalf("an invalid mapping transfers nothing, got %d refs", len(refs))
	}
}
