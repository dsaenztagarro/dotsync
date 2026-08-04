// Package transfer implements the write side of a sync — a faithful port of
// Ruby's Dotsync::FileTransfer. It copies files atomically (temp file + rename)
// preserving the source's mode and symlink targets, handles type conflicts,
// and removes stale destination files in force mode (from precomputed removals
// or, as a fallback, by scanning the destination).
package transfer

import (
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/dsaenztagarro/dotsync/internal/derr"
	"github.com/dsaenztagarro/dotsync/internal/fsutil"
	"github.com/dsaenztagarro/dotsync/internal/model"
)

// Transfer applies a mapping's source to its destination.
type Transfer struct {
	m        *model.Mapping
	src      string
	dest     string
	force    bool
	removals []string // nil => scan destination in force mode; non-nil => use as-is
}

// New builds a Transfer. Pass removals (even empty, non-nil) to remove exactly
// those precomputed absolute paths in force mode; pass nil to fall back to
// scanning the destination tree (used by backup transfers). Mirrors
// FileTransfer#initialize(mapping, removals:).
func New(m *model.Mapping, removals []string) *Transfer {
	return &Transfer{
		m:        m,
		src:      m.Src(),
		dest:     m.Dest(),
		force:    m.Force(),
		removals: removals,
	}
}

// Run performs the transfer. Mirrors FileTransfer#transfer.
func (t *Transfer) Run() error {
	if fsutil.IsFile(t.src) {
		// Overwriting a real (non-symlink) directory that is the exact target
		// is a conflict.
		if !isSymlink(t.dest) && fsutil.IsDir(t.dest) {
			if filepath.Base(t.dest) == filepath.Base(t.src) {
				return &derr.TypeConflictError{Msg: fmt.Sprintf("Cannot overwrite directory '%s' with file '%s'", t.dest, t.src)}
			}
		}
		target := t.dest
		if fsutil.IsDir(t.dest) {
			target = filepath.Join(t.dest, filepath.Base(t.src))
		}
		return t.transferFile(t.src, target)
	}

	if t.force {
		var err error
		if t.removals != nil {
			err = t.removePrecomputed()
		} else {
			err = t.cleanupFolder(t.dest)
		}
		if err != nil {
			return err
		}
	}
	return t.transferFolder(t.src, t.dest)
}

func (t *Transfer) transferFile(src, dst string) error {
	// A directory at the destination (following symlinks) cannot be overwritten
	// with a file.
	if fsutil.IsDir(dst) {
		return &derr.TypeConflictError{Msg: fmt.Sprintf("Cannot overwrite directory '%s' with file '%s'", dst, src)}
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return mapTransferErr(err)
	}

	// Atomic write: copy to a pid-unique temp file, then rename over the
	// destination. Prevents a partially written file on interruption.
	tmp := fmt.Sprintf("%s.tmp.%d", dst, os.Getpid())
	if err := copyFilePreservingMode(src, tmp); err != nil {
		os.Remove(tmp)
		return err
	}
	if err := os.Rename(tmp, dst); err != nil {
		os.Remove(tmp)
		return mapTransferErr(err)
	}
	return nil
}

// copyFilePreservingMode copies src to tmp, creating tmp with src's file mode
// (as Ruby's FileUtils.cp does by opening the destination with the source's
// stat mode). The mode is subject to the process umask, matching Ruby.
func copyFilePreservingMode(src, tmp string) error {
	info, err := os.Stat(src)
	if err != nil {
		return mapTransferErr(err)
	}
	in, err := os.Open(src)
	if err != nil {
		return mapTransferErr(err)
	}
	defer in.Close()

	out, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, info.Mode().Perm())
	if err != nil {
		return mapTransferErr(err)
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return mapTransferErr(err)
	}
	if err := out.Close(); err != nil {
		return mapTransferErr(err)
	}
	return nil
}

func (t *Transfer) transferFolder(src, dst string) error {
	if err := os.MkdirAll(dst, 0o755); err != nil {
		return mapTransferErr(err)
	}
	entries, err := os.ReadDir(src) // sorted, includes dotfiles, excludes . and ..
	if err != nil {
		return mapTransferErr(err)
	}
	for _, entry := range entries {
		full := filepath.Join(src, entry.Name())
		if !t.m.BidirectionalInclude(full) {
			continue
		}
		if t.m.Ignore(full) {
			continue
		}
		target := filepath.Join(dst, entry.Name())
		switch {
		case entry.Type()&os.ModeSymlink != 0:
			if err := t.transferSymlink(full, target); err != nil {
				return err
			}
		case entry.IsDir():
			if err := t.transferFolder(full, target); err != nil {
				return err
			}
		case entry.Type().IsRegular():
			if err := t.transferFile(full, target); err != nil {
				return err
			}
			// Non-regular, non-dir, non-symlink entries (fifos, sockets) are
			// skipped, matching Ruby's File.file?/File.directory? guards.
		}
	}
	return nil
}

func (t *Transfer) transferSymlink(src, dst string) error {
	// Overwriting a real (non-symlink) directory with a symlink is a conflict.
	if li, err := os.Lstat(dst); err == nil && li.Mode()&os.ModeSymlink == 0 && li.IsDir() {
		return &derr.TypeConflictError{Msg: fmt.Sprintf("Cannot overwrite directory '%s' with symlink '%s'", dst, src)}
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return mapTransferErr(err)
	}
	target, err := os.Readlink(src)
	if err != nil {
		return &derr.SymlinkError{Msg: "Failed to create symlink: " + err.Error(), Err: err}
	}
	// Remove any existing entry at dst (regular file, dir, or symlink incl.
	// broken) before recreating the link.
	if _, err := os.Lstat(dst); err == nil {
		if err := os.Remove(dst); err != nil {
			return mapSymlinkErr(err)
		}
	}
	if err := os.Symlink(target, dst); err != nil {
		return mapSymlinkErr(err)
	}
	return nil
}

// removePrecomputed deletes the precomputed removal paths and prunes now-empty
// parent directories up to the destination root. Mirrors remove_precomputed_files.
func (t *Transfer) removePrecomputed() error {
	destExpanded := filepath.Clean(t.dest)
	for _, path := range t.removals {
		if !fsutil.IsFile(path) {
			continue
		}
		if err := os.Remove(path); err != nil {
			return mapTransferErr(err)
		}
		dir := filepath.Dir(path)
		for dir != destExpanded && strings.HasPrefix(dir, destExpanded) {
			empty, err := dirEmpty(dir)
			if err != nil {
				return mapTransferErr(err)
			}
			if !empty {
				break
			}
			if err := os.Remove(dir); err != nil {
				return mapTransferErr(err)
			}
			dir = filepath.Dir(dir)
		}
	}
	return nil
}

// cleanupFolder removes destination files with no source counterpart, honoring
// both include? and ignore?, pruning excluded/ignored subtrees. Mirrors
// cleanup_folder (the removals==nil fallback used by backup transfers). Like
// Ruby's Find pre-order traversal, only directories that are already empty when
// visited are removed.
func (t *Transfer) cleanupFolder(dst string) error {
	target := filepath.Clean(dst)
	return filepath.WalkDir(target, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return mapTransferErr(err)
		}
		if path == target {
			return nil
		}
		if t.m.Ignore(path) {
			if d.IsDir() {
				return fs.SkipDir
			}
			return nil
		}
		if !t.m.Include(path) {
			if d.IsDir() {
				return fs.SkipDir
			}
			return nil
		}
		if d.IsDir() {
			empty, derr := dirEmpty(path)
			if derr != nil {
				return mapTransferErr(derr)
			}
			if empty {
				if err := os.Remove(path); err != nil {
					return mapTransferErr(err)
				}
				return fs.SkipDir
			}
			return nil
		}
		if fsutil.IsFile(path) {
			if err := os.Remove(path); err != nil {
				return mapTransferErr(err)
			}
		}
		return nil
	})
}

// --- helpers ---

func isSymlink(p string) bool {
	li, err := os.Lstat(p)
	return err == nil && li.Mode()&os.ModeSymlink != 0
}

func dirEmpty(dir string) (bool, error) {
	f, err := os.Open(dir)
	if err != nil {
		return false, err
	}
	defer f.Close()
	names, err := f.Readdirnames(1)
	if err == io.EOF {
		return true, nil
	}
	if err != nil {
		return false, err
	}
	return len(names) == 0, nil
}

// mapTransferErr classifies an OS error into the FileTransferError family,
// matching the Ruby rescue chain (EACCES/EPERM, ENOSPC, else generic).
func mapTransferErr(err error) error {
	switch {
	case errors.Is(err, os.ErrPermission):
		return &derr.PermissionError{Msg: "Permission denied: " + err.Error(), Err: err}
	case errors.Is(err, syscall.ENOSPC):
		return &derr.DiskFullError{Msg: "Disk full: " + err.Error(), Err: err}
	default:
		return &derr.FileTransferError{Msg: "Transfer failed: " + err.Error(), Err: err}
	}
}

func mapSymlinkErr(err error) error {
	if errors.Is(err, os.ErrPermission) {
		return &derr.PermissionError{Msg: "Permission denied creating symlink: " + err.Error(), Err: err}
	}
	return &derr.SymlinkError{Msg: "Failed to create symlink: " + err.Error(), Err: err}
}
