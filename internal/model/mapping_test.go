package model

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/dsaenztagarro/dotsync/internal/paths"
)

func mkdirAll(t *testing.T, p string) {
	t.Helper()
	if err := os.MkdirAll(p, 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", p, err)
	}
}

func touch(t *testing.T, p string) {
	t.Helper()
	mkdirAll(t, filepath.Dir(p))
	if err := os.WriteFile(p, []byte("x"), 0o644); err != nil {
		t.Fatalf("touch %s: %v", p, err)
	}
}

// dirMapping builds a src/dest directory mapping under a temp root.
func dirMapping(t *testing.T, only, ignore []string, force bool) *Mapping {
	t.Helper()
	root := t.TempDir()
	src := filepath.Join(root, "src")
	dest := filepath.Join(root, "dest")
	mkdirAll(t, src)
	mkdirAll(t, dest)
	return New(Attributes{Src: src, Dest: dest, Only: only, Ignore: ignore, Force: force})
}

func TestGlobInclude(t *testing.T) {
	m := dirMapping(t, []string{"local.*.plist"}, nil, false)

	if !m.Include(filepath.Join(m.Src(), "local.brew.upgrade.plist")) {
		t.Error("glob should match local.brew.upgrade.plist")
	}
	if m.Include(filepath.Join(m.Src(), "com.apple.something.plist")) {
		t.Error("glob should not match com.apple.something.plist")
	}
	if !m.Include(m.Src()) {
		t.Error("src directory itself should be included")
	}
}

func TestSingleCharAndBracketInclude(t *testing.T) {
	q := dirMapping(t, []string{"config.?"}, nil, false)
	if !q.Include(filepath.Join(q.Src(), "config.a")) {
		t.Error("? should match config.a")
	}
	if q.Include(filepath.Join(q.Src(), "config.ab")) {
		t.Error("? should not match config.ab")
	}

	b := dirMapping(t, []string{"log.[0-9]"}, nil, false)
	if !b.Include(filepath.Join(b.Src(), "log.1")) {
		t.Error("[0-9] should match log.1")
	}
	if b.Include(filepath.Join(b.Src(), "log.a")) {
		t.Error("[0-9] should not match log.a")
	}
}

func TestMixedGlobAndExactInclude(t *testing.T) {
	m := dirMapping(t, []string{"local.*.plist", "README.md"}, nil, false)
	if !m.Include(filepath.Join(m.Src(), "local.ollama.plist")) {
		t.Error("should match via glob")
	}
	if !m.Include(filepath.Join(m.Src(), "README.md")) {
		t.Error("should match via exact path")
	}
	if m.Include(filepath.Join(m.Src(), "com.apple.plist")) {
		t.Error("should reject non-matching")
	}
}

func TestBidirectionalIncludeAndPrune(t *testing.T) {
	m := dirMapping(t, []string{"local.*.plist"}, nil, false)

	if !m.BidirectionalInclude(filepath.Join(m.Src(), "local.brew.upgrade.plist")) {
		t.Error("bidirectional should match the glob target")
	}
	if !m.BidirectionalInclude(m.Src()) {
		t.Error("bidirectional should return true for the parent dir (allow traversal)")
	}
	if m.BidirectionalInclude(filepath.Join(m.Src(), "com.apple.plist")) {
		t.Error("bidirectional should reject non-matching file")
	}

	if m.ShouldPruneDirectory(m.Src()) {
		t.Error("should not prune the src directory")
	}
	if !m.ShouldPruneDirectory(filepath.Join(m.Src(), "subdir")) {
		t.Error("should prune unrelated subdirectory")
	}
}

func TestSkip(t *testing.T) {
	m := dirMapping(t, []string{"local.*.plist"}, nil, false)
	if m.Skip(filepath.Join(m.Src(), "local.brew.upgrade.plist")) {
		t.Error("should not skip matching file")
	}
	if !m.Skip(filepath.Join(m.Src(), "com.apple.plist")) {
		t.Error("should skip non-matching file")
	}
}

func TestNoInclusionsIncludesEverything(t *testing.T) {
	m := dirMapping(t, nil, nil, false)
	if m.HasInclusions() {
		t.Error("expected no inclusions")
	}
	if !m.Include(filepath.Join(m.Src(), "anything")) {
		t.Error("without inclusions everything is included")
	}
	if m.ShouldPruneDirectory(filepath.Join(m.Src(), "anything")) {
		t.Error("without inclusions nothing is pruned (absent ignores)")
	}
}

func TestIgnoreRawPrefixSemantics(t *testing.T) {
	m := dirMapping(t, nil, []string{"foo"}, false)
	// Mapping#ignore? uses a raw string prefix, so "foo" also matches "foobar".
	if !m.Ignore(filepath.Join(m.Src(), "foobar")) {
		t.Error("raw-prefix ignore should match sibling with shared prefix")
	}
	if !m.Ignore(filepath.Join(m.Src(), "foo", "child")) {
		t.Error("ignore should match nested path")
	}
	if m.Ignore(filepath.Join(m.Src(), "bar")) {
		t.Error("unrelated path should not be ignored")
	}
}

func TestValidity(t *testing.T) {
	t.Run("both dirs valid", func(t *testing.T) {
		m := dirMapping(t, nil, nil, false)
		if !m.Valid() || m.InvalidityReason() != Valid {
			t.Errorf("expected valid, got %q", m.InvalidityReason())
		}
	})

	t.Run("src missing", func(t *testing.T) {
		root := t.TempDir()
		dest := filepath.Join(root, "dest")
		mkdirAll(t, dest)
		m := New(Attributes{Src: filepath.Join(root, "src"), Dest: dest})
		if m.InvalidityReason() != SrcMissing {
			t.Errorf("got %q, want src_missing", m.InvalidityReason())
		}
	})

	t.Run("dest missing", func(t *testing.T) {
		root := t.TempDir()
		src := filepath.Join(root, "src")
		mkdirAll(t, src)
		m := New(Attributes{Src: src, Dest: filepath.Join(root, "dest")})
		if m.InvalidityReason() != DestMissing {
			t.Errorf("got %q, want dest_missing", m.InvalidityReason())
		}
	})

	t.Run("paths same", func(t *testing.T) {
		root := t.TempDir()
		src := filepath.Join(root, "src")
		mkdirAll(t, src)
		m := New(Attributes{Src: src, Dest: src})
		if m.InvalidityReason() != PathsSame {
			t.Errorf("got %q, want paths_same", m.InvalidityReason())
		}
	})

	t.Run("paths nested", func(t *testing.T) {
		root := t.TempDir()
		src := filepath.Join(root, "src")
		dest := filepath.Join(src, "subdir")
		mkdirAll(t, dest)
		m := New(Attributes{Src: src, Dest: dest})
		if m.InvalidityReason() != PathsNested {
			t.Errorf("got %q, want paths_nested", m.InvalidityReason())
		}
	})

	t.Run("file present in src only is valid", func(t *testing.T) {
		root := t.TempDir()
		src := filepath.Join(root, "file")
		touch(t, src)
		m := New(Attributes{Src: src, Dest: filepath.Join(root, "dest_file")})
		if !m.Valid() {
			t.Errorf("src-only file with existing dest parent should be valid, got %q", m.InvalidityReason())
		}
	})
}

func TestDestCreatable(t *testing.T) {
	t.Run("dir src, missing dest", func(t *testing.T) {
		root := t.TempDir()
		src := filepath.Join(root, "src")
		mkdirAll(t, src)
		m := New(Attributes{Src: src, Dest: filepath.Join(root, "dest")})
		if !m.DestCreatable() {
			t.Error("expected creatable")
		}
	})

	t.Run("file src, missing parent", func(t *testing.T) {
		root := t.TempDir()
		src := filepath.Join(root, "file")
		touch(t, src)
		m := New(Attributes{Src: src, Dest: filepath.Join(root, "missing_parent", "file")})
		if !m.DestCreatable() {
			t.Error("expected creatable")
		}
	})

	t.Run("already valid is not creatable", func(t *testing.T) {
		m := dirMapping(t, nil, nil, false)
		if m.DestCreatable() {
			t.Error("valid mapping is not creatable")
		}
	})
}

func TestManifestKey(t *testing.T) {
	t.Run("no sync_type", func(t *testing.T) {
		m := New(Attributes{Src: "/a", Dest: "/b"})
		if got := m.ManifestKey(); got != "" {
			t.Errorf("got %q, want empty", got)
		}
	})

	t.Run("sync_type no subpath", func(t *testing.T) {
		root := t.TempDir()
		t.Setenv("XDG_BIN_HOME", filepath.Join(root, "bin"))
		t.Setenv("XDG_BIN_HOME_MIRROR", filepath.Join(root, "bin_mirror"))
		m := New(Attributes{Src: "$XDG_BIN_HOME_MIRROR", Dest: "$XDG_BIN_HOME", SyncType: "xdg_bin"})
		if got := m.ManifestKey(); got != "xdg_bin" {
			t.Errorf("got %q, want xdg_bin", got)
		}
	})

	t.Run("sync_type with subpath", func(t *testing.T) {
		root := t.TempDir()
		t.Setenv("XDG_CONFIG_HOME", filepath.Join(root, "config"))
		t.Setenv("XDG_CONFIG_HOME_MIRROR", filepath.Join(root, "config_mirror"))
		m := New(Attributes{Src: "$XDG_CONFIG_HOME_MIRROR/nvim", Dest: "$XDG_CONFIG_HOME/nvim", SyncType: "xdg_config"})
		if got := m.ManifestKey(); got != "xdg_config--nvim" {
			t.Errorf("got %q, want xdg_config--nvim", got)
		}
	})
}

func TestApplyTo(t *testing.T) {
	root := t.TempDir()
	src := filepath.Join(root, "src")
	dest := filepath.Join(root, "dest")
	mkdirAll(t, src)
	mkdirAll(t, dest)
	m := New(Attributes{Src: src, Dest: dest, Force: true})

	t.Run("absolute path", func(t *testing.T) {
		abs := filepath.Join(m.Src(), "subdir/file.txt")
		nm := m.ApplyTo(abs)
		if nm.Src() != paths.SanitizePath(filepath.Join(src, "subdir/file.txt")) {
			t.Errorf("src = %q", nm.Src())
		}
		if nm.Dest() != paths.SanitizePath(filepath.Join(dest, "subdir/file.txt")) {
			t.Errorf("dest = %q", nm.Dest())
		}
		if !nm.Force() {
			t.Error("force flag should be preserved")
		}
	})

	t.Run("relative path", func(t *testing.T) {
		nm := m.ApplyTo("subdir/file.txt")
		if nm.Src() != paths.SanitizePath(filepath.Join(src, "subdir/file.txt")) {
			t.Errorf("src = %q", nm.Src())
		}
		if nm.Dest() != paths.SanitizePath(filepath.Join(dest, "subdir/file.txt")) {
			t.Errorf("dest = %q", nm.Dest())
		}
	})
}

func TestIgnoresExpandToBothSides(t *testing.T) {
	m := dirMapping(t, nil, []string{"ignored_file"}, false)
	want := map[string]bool{
		filepath.Join(m.Src(), "ignored_file"):  true,
		filepath.Join(m.Dest(), "ignored_file"): true,
	}
	for _, ig := range m.Ignores() {
		delete(want, ig)
	}
	if len(want) != 0 {
		t.Errorf("ignores missing expansions: %v; got %v", want, m.Ignores())
	}
}
