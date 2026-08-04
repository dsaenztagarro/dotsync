package engine

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/dsaenztagarro/dotsync/internal/model"
)

func mkdirAll(t *testing.T, p string) {
	t.Helper()
	if err := os.MkdirAll(p, 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", p, err)
	}
}

func write(t *testing.T, p, content string) {
	t.Helper()
	mkdirAll(t, filepath.Dir(p))
	if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
		t.Fatalf("write %s: %v", p, err)
	}
}

// setupRoot returns fresh src and dest directories under a temp root.
func setupRoot(t *testing.T) (src, dest string) {
	t.Helper()
	root := t.TempDir()
	src = filepath.Join(root, "src")
	dest = filepath.Join(root, "dest")
	mkdirAll(t, src)
	mkdirAll(t, dest)
	return src, dest
}

func diffOf(t *testing.T, src, dest string, only, ignore []string, force bool) Diff {
	t.Helper()
	m := model.New(model.Attributes{Src: src, Dest: dest, Only: only, Ignore: ignore, Force: force})
	d, err := New(m).Diff()
	if err != nil {
		t.Fatalf("Diff() error: %v", err)
	}
	return d
}

func contains(list []string, want string) bool {
	for _, s := range list {
		if s == want {
			return true
		}
	}
	return false
}

func TestDirDiffAddModRemove(t *testing.T) {
	src, dest := setupRoot(t)
	write(t, filepath.Join(src, "fold", "file1.txt"), "new file content")
	write(t, filepath.Join(src, "fold", "file3.txt"), "content")
	write(t, filepath.Join(dest, "fold", "file2.txt"), "old file content")
	write(t, filepath.Join(dest, "fold", "file3.txt"), "different content")

	d := diffOf(t, src, dest, nil, nil, true)

	if !contains(d.Additions, filepath.Join(dest, "fold", "file1.txt")) {
		t.Errorf("additions missing file1.txt: %v", d.Additions)
	}
	if !contains(d.Removals, filepath.Join(dest, "fold", "file2.txt")) {
		t.Errorf("removals missing file2.txt: %v", d.Removals)
	}
	if !contains(d.Modifications, filepath.Join(dest, "fold", "file3.txt")) {
		t.Errorf("modifications missing file3.txt: %v", d.Modifications)
	}
	// Modification pairs carry the concrete sanitized paths.
	found := false
	for _, p := range d.ModificationPairs {
		if p.RelPath == "fold/file3.txt" && p.Src == filepath.Join(src, "fold", "file3.txt") {
			found = true
		}
	}
	if !found {
		t.Errorf("modification pair for file3 missing: %v", d.ModificationPairs)
	}
}

func TestDirDiffIgnoreDirectory(t *testing.T) {
	src, dest := setupRoot(t)
	write(t, filepath.Join(src, "fold", "file1.txt"), "new")
	write(t, filepath.Join(dest, "fold", "file2.txt"), "old")

	d := diffOf(t, src, dest, nil, []string{"fold"}, true)

	if contains(d.Additions, filepath.Join(dest, "fold", "file1.txt")) {
		t.Errorf("ignored dir leaked into additions: %v", d.Additions)
	}
	if contains(d.Removals, filepath.Join(dest, "fold", "file2.txt")) {
		t.Errorf("ignored dir leaked into removals: %v", d.Removals)
	}
}

func TestDirDiffOnlyFile(t *testing.T) {
	src, dest := setupRoot(t)
	write(t, filepath.Join(src, "fold", "file1.txt"), "new")
	write(t, filepath.Join(src, "fold", "file3.txt"), "content")
	write(t, filepath.Join(dest, "fold", "file2.txt"), "old")
	write(t, filepath.Join(dest, "fold", "file3.txt"), "different")

	d := diffOf(t, src, dest, []string{filepath.Join("fold", "file2.txt")}, nil, true)

	if contains(d.Additions, filepath.Join(dest, "fold", "file1.txt")) {
		t.Errorf("non-included addition leaked: %v", d.Additions)
	}
	if !contains(d.Removals, filepath.Join(dest, "fold", "file2.txt")) {
		t.Errorf("included removal missing: %v", d.Removals)
	}
	if contains(d.Modifications, filepath.Join(dest, "fold", "file3.txt")) {
		t.Errorf("non-included modification leaked: %v", d.Modifications)
	}
}

func TestDirDiffOnlySpecificNestedFiles(t *testing.T) {
	src, dest := setupRoot(t)
	write(t, filepath.Join(src, "bundle", "config"), "new bundle config")
	write(t, filepath.Join(src, "ghc", "ghci.conf"), "new ghc config")
	write(t, filepath.Join(src, "bundle", "other.txt"), "other")
	write(t, filepath.Join(src, "cabal", "config"), "cabal config")
	write(t, filepath.Join(dest, "bundle", "config"), "old bundle config")
	write(t, filepath.Join(dest, "bundle", "obsolete.txt"), "obsolete")
	write(t, filepath.Join(dest, "cabal", "config"), "old cabal config")

	d := diffOf(t, src, dest, []string{"bundle/config", "ghc/ghci.conf"}, nil, true)

	if !contains(d.Additions, filepath.Join(dest, "ghc/ghci.conf")) {
		t.Errorf("expected ghc/ghci.conf addition: %v", d.Additions)
	}
	if contains(d.Additions, filepath.Join(dest, "bundle/other.txt")) ||
		contains(d.Additions, filepath.Join(dest, "cabal/config")) {
		t.Errorf("unexpected additions: %v", d.Additions)
	}
	if !contains(d.Modifications, filepath.Join(dest, "bundle/config")) {
		t.Errorf("expected bundle/config modification: %v", d.Modifications)
	}
	if contains(d.Modifications, filepath.Join(dest, "cabal/config")) {
		t.Errorf("unrelated modification leaked: %v", d.Modifications)
	}
	// Sibling files in an only-managed directory must not be removed.
	if contains(d.Removals, filepath.Join(dest, "bundle/obsolete.txt")) ||
		contains(d.Removals, filepath.Join(dest, "cabal/config")) {
		t.Errorf("unexpected removals: %v", d.Removals)
	}
}

func TestDirDiffGlobOnly(t *testing.T) {
	src, dest := setupRoot(t)
	write(t, filepath.Join(src, "local.brew.plist"), "new brew")
	write(t, filepath.Join(src, "local.notes.plist"), "new notes")
	write(t, filepath.Join(src, "com.apple.finder.plist"), "finder")
	write(t, filepath.Join(src, "README.md"), "readme")
	write(t, filepath.Join(dest, "local.brew.plist"), "old brew")

	d := diffOf(t, src, dest, []string{"local.*.plist"}, nil, true)

	if !contains(d.Additions, filepath.Join(dest, "local.notes.plist")) {
		t.Errorf("glob addition missing: %v", d.Additions)
	}
	if contains(d.Additions, filepath.Join(dest, "com.apple.finder.plist")) ||
		contains(d.Additions, filepath.Join(dest, "README.md")) {
		t.Errorf("non-matching additions leaked: %v", d.Additions)
	}
	if !contains(d.Modifications, filepath.Join(dest, "local.brew.plist")) {
		t.Errorf("glob modification missing: %v", d.Modifications)
	}
}

func TestDirDiffNoDifferences(t *testing.T) {
	src, dest := setupRoot(t)
	write(t, filepath.Join(src, "file1.txt"), "content")
	write(t, filepath.Join(dest, "file1.txt"), "content")

	d := diffOf(t, src, dest, nil, nil, true)
	if !d.Empty() {
		t.Errorf("expected empty diff, got %+v", d)
	}
}

func TestFileMappingAddition(t *testing.T) {
	src, dest := setupRoot(t)
	srcFile := filepath.Join(src, "file.txt")
	destFile := filepath.Join(dest, "file.txt")
	write(t, srcFile, "src content")

	d := diffOf(t, srcFile, destFile, nil, nil, true)
	if !contains(d.Additions, destFile) {
		t.Errorf("expected file addition: %v", d.Additions)
	}
	if len(d.Modifications) != 0 || len(d.Removals) != 0 {
		t.Errorf("unexpected mods/removals: %+v", d)
	}
}

func TestFileMappingModification(t *testing.T) {
	src, dest := setupRoot(t)
	srcFile := filepath.Join(src, "file.txt")
	destFile := filepath.Join(dest, "file.txt")

	// Same size, different content -> still a modification (content compare).
	write(t, srcFile, "12345")
	write(t, destFile, "abcde")

	d := diffOf(t, srcFile, destFile, nil, nil, true)
	if !contains(d.Modifications, destFile) {
		t.Errorf("expected file modification: %v", d.Modifications)
	}
}

func TestFileMappingUnchanged(t *testing.T) {
	src, dest := setupRoot(t)
	srcFile := filepath.Join(src, "file.txt")
	destFile := filepath.Join(dest, "file.txt")
	write(t, srcFile, "same content")
	write(t, destFile, "same content")

	d := diffOf(t, srcFile, destFile, nil, nil, true)
	if !d.Empty() {
		t.Errorf("expected empty diff, got %+v", d)
	}
}
