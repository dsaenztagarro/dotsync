package transfer

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/dsaenztagarro/dotsync/internal/derr"
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

func read(t *testing.T, p string) string {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatalf("read %s: %v", p, err)
	}
	return string(b)
}

func exists(p string) bool {
	_, err := os.Lstat(p)
	return err == nil
}

func srcDest(t *testing.T) (src, dest string) {
	t.Helper()
	root := t.TempDir()
	src = filepath.Join(root, "src")
	dest = filepath.Join(root, "dest")
	mkdirAll(t, src)
	mkdirAll(t, dest)
	return src, dest
}

func run(t *testing.T, src, dest string, only, ignore []string, force bool, removals []string) {
	t.Helper()
	m := model.New(model.Attributes{Src: src, Dest: dest, Only: only, Ignore: ignore, Force: force})
	if err := New(m, removals).Run(); err != nil {
		t.Fatalf("transfer: %v", err)
	}
}

// buildFileStructure mirrors the spec's helper of the same name.
func buildFileStructure(t *testing.T, origin string) {
	t.Helper()
	base := filepath.Base(origin)
	files := []string{
		"folder1/file1.txt",
		"folder2/file2.txt",
		"folder3/subfolder1/file3.txt",
		"folder3/subfolder2/file4.txt",
		"folder3/subfolder3/sub2folder1/file5.txt",
		"folder3/subfolder3/sub2folder2/file6.txt",
		"file7.txt",
		"file8.txt",
	}
	for _, f := range files {
		write(t, filepath.Join(origin, f), base+" content")
	}
}

func TestTransferBasicFile(t *testing.T) {
	src, dest := srcDest(t)
	write(t, filepath.Join(src, "testfile"), "x")
	run(t, src, dest, nil, nil, false, nil)
	if !exists(filepath.Join(dest, "testfile")) {
		t.Error("testfile not transferred")
	}
}

func TestTransferReplacesExistingFile(t *testing.T) {
	src, dest := srcDest(t)
	write(t, filepath.Join(src, "testfile"), "source content")
	write(t, filepath.Join(dest, "testfile"), "destination content")
	run(t, src, dest, nil, nil, false, nil)
	if got := read(t, filepath.Join(dest, "testfile")); got != "source content" {
		t.Errorf("got %q", got)
	}
}

func TestTransferPreservesFileMode(t *testing.T) {
	src, dest := srcDest(t)
	exe := filepath.Join(src, "script.sh")
	write(t, exe, "#!/bin/sh\n")
	if err := os.Chmod(exe, 0o755); err != nil {
		t.Fatal(err)
	}
	run(t, src, dest, nil, nil, false, nil)
	info, err := os.Stat(filepath.Join(dest, "script.sh"))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm()&0o100 == 0 {
		t.Errorf("executable bit not preserved: %v", info.Mode().Perm())
	}
}

func TestTransferIgnorePaths(t *testing.T) {
	src, dest := srcDest(t)
	buildFileStructure(t, src)
	ignore := []string{"folder2", "folder3/subfolder2", "folder3/subfolder3/sub2folder2", "file7.txt"}
	run(t, src, dest, nil, ignore, false, nil)

	present := []string{"folder1/file1.txt", "folder3/subfolder1/file3.txt", "folder3/subfolder3/sub2folder1/file5.txt", "file8.txt"}
	absent := []string{"folder2/file2.txt", "folder3/subfolder2/file4.txt", "folder3/subfolder3/sub2folder2/file6.txt", "file7.txt"}
	for _, f := range present {
		if !exists(filepath.Join(dest, f)) {
			t.Errorf("expected %s present", f)
		}
	}
	for _, f := range absent {
		if exists(filepath.Join(dest, f)) {
			t.Errorf("expected %s absent", f)
		}
	}
}

func TestTransferOnlyPaths(t *testing.T) {
	src, dest := srcDest(t)
	buildFileStructure(t, src)
	only := []string{"folder1", "folder3/subfolder1", "folder3/subfolder3/sub2folder1", "file8.txt"}
	run(t, src, dest, only, nil, false, nil)

	present := []string{"folder1/file1.txt", "folder3/subfolder1/file3.txt", "folder3/subfolder3/sub2folder1/file5.txt", "file8.txt"}
	absent := []string{"folder2/file2.txt", "folder3/subfolder2/file4.txt", "folder3/subfolder3/sub2folder2/file6.txt", "file7.txt"}
	for _, f := range present {
		if !exists(filepath.Join(dest, f)) {
			t.Errorf("expected %s present", f)
		}
	}
	for _, f := range absent {
		if exists(filepath.Join(dest, f)) {
			t.Errorf("expected %s absent", f)
		}
	}
}

func TestTransferGlobOnly(t *testing.T) {
	src, dest := srcDest(t)
	write(t, filepath.Join(src, "local.brew.upgrade.plist"), "brew")
	write(t, filepath.Join(src, "local.ollama.plist"), "ollama")
	write(t, filepath.Join(src, "com.apple.something.plist"), "apple")
	write(t, filepath.Join(src, "README.md"), "readme")
	run(t, src, dest, []string{"local.*.plist"}, nil, false, nil)

	if !exists(filepath.Join(dest, "local.brew.upgrade.plist")) || !exists(filepath.Join(dest, "local.ollama.plist")) {
		t.Error("glob-matching files should transfer")
	}
	if exists(filepath.Join(dest, "com.apple.something.plist")) || exists(filepath.Join(dest, "README.md")) {
		t.Error("non-matching files should not transfer")
	}
}

func TestTransferNestedOnly(t *testing.T) {
	src, dest := srcDest(t)
	write(t, filepath.Join(src, "deep/nested/path/config.yml"), "cfg")
	write(t, filepath.Join(src, "deep/nested/path/other.yml"), "other")
	write(t, filepath.Join(src, "deep/nested/parent_file.txt"), "parent")
	run(t, src, dest, []string{"deep/nested/path/config.yml"}, nil, false, nil)

	if !exists(filepath.Join(dest, "deep/nested/path/config.yml")) {
		t.Error("nested only file should transfer")
	}
	if exists(filepath.Join(dest, "deep/nested/path/other.yml")) || exists(filepath.Join(dest, "deep/nested/parent_file.txt")) {
		t.Error("siblings should not transfer")
	}
}

func TestTransferForceCleanupWithIgnore(t *testing.T) {
	// removals == nil path -> cleanupFolder; src empty, dest populated.
	src, dest := srcDest(t)
	buildFileStructure(t, dest)
	ignore := []string{"folder2/file2.txt", "folder3/subfolder2", "folder3/subfolder3/sub2folder1/file5.txt", "file7.txt"}
	run(t, src, dest, nil, ignore, true, nil)

	kept := []string{"folder2/file2.txt", "folder3/subfolder2/file4.txt", "folder3/subfolder3/sub2folder1/file5.txt", "file7.txt"}
	removed := []string{"folder1/file1.txt", "folder3/subfolder1/file3.txt", "folder3/subfolder3/sub2folder2/file6.txt", "file8.txt"}
	for _, f := range kept {
		if !exists(filepath.Join(dest, f)) {
			t.Errorf("ignored file %s should be kept", f)
		}
	}
	for _, f := range removed {
		if exists(filepath.Join(dest, f)) {
			t.Errorf("stale file %s should be removed", f)
		}
	}
}

func TestTransferForceOnlyPreservesUnrelated(t *testing.T) {
	src, dest := srcDest(t)
	write(t, filepath.Join(src, "folder1/file1.txt"), "new src content")
	write(t, filepath.Join(src, "file8.txt"), "new src content")
	// unrelated + stale-in-managed dest content
	write(t, filepath.Join(dest, "cabal/config"), "cabal config content")
	write(t, filepath.Join(dest, "ghc/ghci.conf"), "ghc config content")
	write(t, filepath.Join(dest, "folder1/old_file.txt"), "old content to remove")

	run(t, src, dest, []string{"folder1", "file8.txt"}, nil, true, nil)

	if !exists(filepath.Join(dest, "cabal/config")) || !exists(filepath.Join(dest, "ghc/ghci.conf")) {
		t.Error("unrelated folders should be preserved")
	}
	if !exists(filepath.Join(dest, "folder1/file1.txt")) || exists(filepath.Join(dest, "folder1/old_file.txt")) {
		t.Error("managed folder should be synced and cleaned")
	}
}

func TestTransferPrecomputedRemovals(t *testing.T) {
	src, dest := srcDest(t)
	write(t, filepath.Join(src, "fold/kept.txt"), "kept content")
	write(t, filepath.Join(dest, "fold/kept.txt"), "old content")
	write(t, filepath.Join(dest, "fold/removed.txt"), "to remove")
	write(t, filepath.Join(dest, "other.txt"), "other content")

	m := model.New(model.Attributes{Src: src, Dest: dest, Force: true})
	removals := []string{filepath.Join(m.Dest(), "fold", "removed.txt"), filepath.Join(m.Dest(), "other.txt")}
	if err := New(m, removals).Run(); err != nil {
		t.Fatal(err)
	}

	if exists(filepath.Join(dest, "fold/removed.txt")) || exists(filepath.Join(dest, "other.txt")) {
		t.Error("precomputed removals should be deleted")
	}
	if got := read(t, filepath.Join(dest, "fold/kept.txt")); got != "kept content" {
		t.Errorf("kept.txt should be synced from source, got %q", got)
	}
}

func TestTransferPrecomputedRemovalsPruneEmptyParent(t *testing.T) {
	src, dest := srcDest(t)
	write(t, filepath.Join(dest, "empty_parent/only_file.txt"), "content")

	m := model.New(model.Attributes{Src: src, Dest: dest, Force: true})
	removals := []string{filepath.Join(m.Dest(), "empty_parent", "only_file.txt")}
	if err := New(m, removals).Run(); err != nil {
		t.Fatal(err)
	}
	if exists(filepath.Join(dest, "empty_parent")) {
		t.Error("empty parent directory should be pruned")
	}
}

func TestTransferPrecomputedRemovalsPreserveNonEmptyParent(t *testing.T) {
	src, dest := srcDest(t)
	write(t, filepath.Join(src, "fold/kept.txt"), "kept content")
	write(t, filepath.Join(dest, "fold/kept.txt"), "kept")
	write(t, filepath.Join(dest, "fold/removed.txt"), "to remove")

	m := model.New(model.Attributes{Src: src, Dest: dest, Force: true})
	removals := []string{filepath.Join(m.Dest(), "fold", "removed.txt")}
	if err := New(m, removals).Run(); err != nil {
		t.Fatal(err)
	}
	if exists(filepath.Join(dest, "fold/removed.txt")) {
		t.Error("removed.txt should be gone")
	}
	if !exists(filepath.Join(dest, "fold")) || !exists(filepath.Join(dest, "fold/kept.txt")) {
		t.Error("non-empty parent should be preserved")
	}
}

func TestTransferFileToFolder(t *testing.T) {
	root := t.TempDir()
	srcFile := filepath.Join(root, "src", "src_file")
	destDir := filepath.Join(root, "dest")
	write(t, srcFile, "source file content")
	mkdirAll(t, destDir)

	m := model.New(model.Attributes{Src: srcFile, Dest: destDir})
	if err := New(m, nil).Run(); err != nil {
		t.Fatal(err)
	}
	if got := read(t, filepath.Join(destDir, "src_file")); got != "source file content" {
		t.Errorf("got %q", got)
	}
}

func TestTransferFileToFile(t *testing.T) {
	root := t.TempDir()
	srcFile := filepath.Join(root, "src", "src_file")
	destFile := filepath.Join(root, "dest", "dest_file")
	write(t, srcFile, "source file content")
	write(t, destFile, "destination file content")

	m := model.New(model.Attributes{Src: srcFile, Dest: destFile})
	if err := New(m, nil).Run(); err != nil {
		t.Fatal(err)
	}
	if got := read(t, destFile); got != "source file content" {
		t.Errorf("got %q", got)
	}
}

func TestTransferTypeConflictDirWithFile(t *testing.T) {
	root := t.TempDir()
	srcFile := filepath.Join(root, "src", "test.txt")
	destDir := filepath.Join(root, "dest", "test.txt")
	write(t, srcFile, "test content")
	mkdirAll(t, destDir) // a directory where a file should go

	m := model.New(model.Attributes{Src: srcFile, Dest: destDir})
	err := New(m, nil).Run()
	var tc *derr.TypeConflictError
	if !errors.As(err, &tc) {
		t.Fatalf("expected TypeConflictError, got %v", err)
	}
}

func TestTransferSymlinks(t *testing.T) {
	t.Run("absolute target", func(t *testing.T) {
		src, dest := srcDest(t)
		real := filepath.Join(src, "real_file.txt")
		write(t, real, "real content")
		if err := os.Symlink(real, filepath.Join(src, "link_to_file")); err != nil {
			t.Fatal(err)
		}
		run(t, src, dest, nil, nil, false, nil)
		got, err := os.Readlink(filepath.Join(dest, "link_to_file"))
		if err != nil || got != real {
			t.Errorf("readlink = %q, %v; want %q", got, err, real)
		}
	})

	t.Run("broken target", func(t *testing.T) {
		src, dest := srcDest(t)
		if err := os.Symlink("/non/existent/path", filepath.Join(src, "broken_link")); err != nil {
			t.Fatal(err)
		}
		run(t, src, dest, nil, nil, false, nil)
		got, err := os.Readlink(filepath.Join(dest, "broken_link"))
		if err != nil || got != "/non/existent/path" {
			t.Errorf("readlink = %q, %v", got, err)
		}
	})

	t.Run("relative target", func(t *testing.T) {
		src, dest := srcDest(t)
		write(t, filepath.Join(src, "target.txt"), "target content")
		if err := os.Symlink("target.txt", filepath.Join(src, "relative_link")); err != nil {
			t.Fatal(err)
		}
		run(t, src, dest, nil, nil, false, nil)
		got, err := os.Readlink(filepath.Join(dest, "relative_link"))
		if err != nil || got != "target.txt" {
			t.Errorf("readlink = %q, %v", got, err)
		}
	})
}

func TestTransferOverwriteDirWithSymlinkConflict(t *testing.T) {
	src, dest := srcDest(t)
	if err := os.Symlink("/some/target", filepath.Join(src, "my_link")); err != nil {
		t.Fatal(err)
	}
	mkdirAll(t, filepath.Join(dest, "my_link"))

	m := model.New(model.Attributes{Src: src, Dest: dest})
	err := New(m, nil).Run()
	var tc *derr.TypeConflictError
	if !errors.As(err, &tc) {
		t.Fatalf("expected TypeConflictError, got %v", err)
	}
}

func TestTransferEmptyDirs(t *testing.T) {
	src, dest := srcDest(t)
	mkdirAll(t, filepath.Join(src, "empty_folder"))
	mkdirAll(t, filepath.Join(src, "parent/child/grandchild"))
	run(t, src, dest, nil, nil, false, nil)

	for _, d := range []string{"empty_folder", "parent/child/grandchild"} {
		info, err := os.Stat(filepath.Join(dest, d))
		if err != nil || !info.IsDir() {
			t.Errorf("expected dir %s, err=%v", d, err)
		}
	}
}

func TestTransferUnicodeFilenames(t *testing.T) {
	src, dest := srcDest(t)
	for _, name := range []string{"файл.txt", "test_😀_file.txt", "テスト_test_测试.txt"} {
		write(t, filepath.Join(src, name), "content")
	}
	run(t, src, dest, nil, nil, false, nil)
	for _, name := range []string{"файл.txt", "test_😀_file.txt", "テスト_test_测试.txt"} {
		if !exists(filepath.Join(dest, name)) {
			t.Errorf("unicode file %q not transferred", name)
		}
	}
}
