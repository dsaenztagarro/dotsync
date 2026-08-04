// Package model holds dotsync's core domain types. Mapping is a faithful port
// of Ruby's Dotsync::Mapping: a source-to-destination path pair with optional
// force/only/ignore/hook behavior, plus the path-matching predicates the diff
// engine relies on. Method semantics mirror the Ruby original exactly; where a
// Ruby quirk is load-bearing (e.g. two different ignore semantics), it is
// reproduced and noted.
package model

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/dsaenztagarro/dotsync/internal/fsutil"
	"github.com/dsaenztagarro/dotsync/internal/paths"
)

// InvalidityReason enumerates why a mapping is not valid. The empty string
// means valid (Ruby returns nil).
type InvalidityReason string

const (
	Valid       InvalidityReason = ""
	PathsSame   InvalidityReason = "paths_same"
	PathsNested InvalidityReason = "paths_nested"
	SrcMissing  InvalidityReason = "src_missing"
	DestMissing InvalidityReason = "dest_missing"
)

// shorthandLocalBases maps a sync shorthand to its local (non-mirror) base
// path expression, used by ManifestKey. Mirrors
// SyncMappings::SHORTHANDS[type][:local].
var shorthandLocalBases = map[string]string{
	"home":       "$HOME",
	"xdg_config": "$XDG_CONFIG_HOME",
	"xdg_data":   "$XDG_DATA_HOME",
	"xdg_cache":  "$XDG_CACHE_HOME",
	"xdg_bin":    "$XDG_BIN_HOME",
}

// Attributes is the normalized input for constructing a Mapping. The config
// layer performs the Ruby `Array(...)` coercion (string-or-array) before
// building this struct.
type Attributes struct {
	Src      string
	Dest     string
	Ignore   []string
	Only     []string
	Force    bool
	Hooks    []string
	SyncType string
}

// Mapping is a single src -> dest synchronization unit.
type Mapping struct {
	originalSrc     string
	originalDest    string
	originalIgnores []string
	originalOnly    []string
	force           bool
	hooks           []string
	syncType        string

	sanitizedSrc     string
	sanitizedDest    string
	sanitizedIgnores []string
	sanitizedOnly    []string
}

// New builds a Mapping, sanitizing paths the way Ruby's initialize does via
// process_paths (each ignore/only entry expands to BOTH src- and dest-relative
// absolute forms).
func New(attrs Attributes) *Mapping {
	m := &Mapping{
		originalSrc:     attrs.Src,
		originalDest:    attrs.Dest,
		originalIgnores: append([]string(nil), attrs.Ignore...),
		originalOnly:    append([]string(nil), attrs.Only...),
		force:           attrs.Force,
		hooks:           append([]string(nil), attrs.Hooks...),
		syncType:        attrs.SyncType,
	}
	m.sanitizedSrc = paths.SanitizePath(attrs.Src)
	m.sanitizedDest = paths.SanitizePath(attrs.Dest)
	m.sanitizedIgnores = expandFilters(m.sanitizedSrc, m.sanitizedDest, attrs.Ignore)
	m.sanitizedOnly = expandFilters(m.sanitizedSrc, m.sanitizedDest, attrs.Only)
	return m
}

// expandFilters joins each entry onto both the sanitized src and dest, matching
// process_paths' flat_map.
func expandFilters(src, dest string, entries []string) []string {
	out := make([]string, 0, len(entries)*2)
	for _, e := range entries {
		out = append(out, filepath.Join(src, e), filepath.Join(dest, e))
	}
	return out
}

// --- accessors (sanitized) ---

func (m *Mapping) Src() string          { return m.sanitizedSrc }
func (m *Mapping) Dest() string         { return m.sanitizedDest }
func (m *Mapping) Ignores() []string    { return m.sanitizedIgnores }
func (m *Mapping) Inclusions() []string { return m.sanitizedOnly }
func (m *Mapping) Force() bool          { return m.force }
func (m *Mapping) Hooks() []string      { return m.hooks }
func (m *Mapping) SyncType() string     { return m.syncType }

// --- accessors (original / unexpanded) ---

func (m *Mapping) OriginalSrc() string       { return m.originalSrc }
func (m *Mapping) OriginalDest() string      { return m.originalDest }
func (m *Mapping) OriginalIgnores() []string { return m.originalIgnores }

func (m *Mapping) HasHooks() bool      { return len(m.hooks) > 0 }
func (m *Mapping) HasInclusions() bool { return len(m.originalOnly) > 0 }
func (m *Mapping) HasIgnores() bool    { return len(m.originalIgnores) > 0 }

// ManifestKey returns the stable orphan-manifest key for a shorthand mapping,
// or "" when the mapping has no sync_type. Mirrors Mapping#manifest_key.
func (m *Mapping) ManifestKey() string {
	if m.syncType == "" {
		return ""
	}
	base, ok := shorthandLocalBases[m.syncType]
	if !ok {
		return m.syncType
	}
	expandedBase := paths.SanitizePath(base)
	switch {
	case m.sanitizedDest == expandedBase:
		return m.syncType
	case strings.HasPrefix(m.sanitizedDest, expandedBase+"/"):
		subpath := strings.TrimPrefix(m.sanitizedDest, expandedBase+"/")
		return m.syncType + "--" + subpath
	default:
		return m.syncType
	}
}

// --- type predicates (touch the filesystem, following symlinks like Ruby) ---

func (m *Mapping) Directories() bool { return isDir(m.sanitizedSrc) && isDir(m.sanitizedDest) }

func (m *Mapping) Files() bool { return m.FilesPresent() || m.FilePresentInSrcOnly() }

func (m *Mapping) FilesPresent() bool { return isFile(m.sanitizedSrc) && isFile(m.sanitizedDest) }

// FilePresentInSrcOnly reports src is a file, dest is missing, but dest's
// parent directory exists.
func (m *Mapping) FilePresentInSrcOnly() bool {
	return isFile(m.sanitizedSrc) && !exists(m.sanitizedDest) && isDir(filepath.Dir(m.sanitizedDest))
}

// --- validity ---

func (m *Mapping) Valid() bool { return m.InvalidityReason() == Valid }

// InvalidityReason mirrors the Ruby ordering: distinctness and nesting are
// checked before existence.
func (m *Mapping) InvalidityReason() InvalidityReason {
	if m.sanitizedSrc == m.sanitizedDest {
		return PathsSame
	}
	if !m.pathsNotNested() {
		return PathsNested
	}
	if m.Directories() || m.Files() {
		return Valid
	}
	if !exists(m.sanitizedSrc) {
		return SrcMissing
	}
	return DestMissing
}

func (m *Mapping) pathsNotNested() bool {
	if strings.HasPrefix(m.sanitizedDest, m.sanitizedSrc+"/") {
		return false
	}
	if strings.HasPrefix(m.sanitizedSrc, m.sanitizedDest+"/") {
		return false
	}
	return true
}

// DestCreatable reports whether the only problem is a missing destination that
// mkdir can fix.
func (m *Mapping) DestCreatable() bool {
	return m.InvalidityReason() == DestMissing && m.fixableByMkdir()
}

func (m *Mapping) fixableByMkdir() bool {
	switch {
	case isDir(m.sanitizedSrc):
		return !exists(m.sanitizedDest)
	case isFile(m.sanitizedSrc):
		return !exists(m.sanitizedDest) && !exists(filepath.Dir(m.sanitizedDest))
	default:
		return false
	}
}

// CreateDest creates the destination directory (or the parent directory for a
// file dest). Mirrors create_dest!.
func (m *Mapping) CreateDest() error {
	target := m.sanitizedDest
	if !isDir(m.sanitizedSrc) {
		target = filepath.Dir(m.sanitizedDest)
	}
	return os.MkdirAll(target, 0o755)
}

// FileChanged reports whether a single-file mapping's src and dest differ,
// size-first. Returns false when the mapping is not a file-to-file pair.
func (m *Mapping) FileChanged() (bool, error) {
	if !m.FilesPresent() {
		return false, nil
	}
	return fsutil.FilesDiffer(m.sanitizedSrc, m.sanitizedDest)
}

func (m *Mapping) BackupPossible() bool { return m.Valid() && exists(m.sanitizedDest) }

// BackupBasename returns the name used for this mapping inside a backup dir, or
// "" when invalid. Mirrors backup_basename.
func (m *Mapping) BackupBasename() (string, bool) {
	if !m.Valid() {
		return "", false
	}
	if !exists(m.sanitizedDest) {
		return filepath.Dir(m.sanitizedDest), true
	}
	return filepath.Base(m.sanitizedDest), true
}

// --- path matching ---

// Include reports whether a path is inside an inclusion (used for file
// filtering). With no inclusions everything is included.
func (m *Mapping) Include(path string) bool {
	if !m.HasInclusions() {
		return true
	}
	if path == m.sanitizedSrc {
		return true
	}
	for _, incl := range m.sanitizedOnly {
		if inclusionMatches(incl, path) {
			return true
		}
	}
	return false
}

// BidirectionalInclude reports whether a path is inside OR an ancestor of an
// inclusion, letting directory traversal descend into parents of included
// files.
func (m *Mapping) BidirectionalInclude(path string) bool {
	if !m.HasInclusions() {
		return true
	}
	if path == m.sanitizedSrc {
		return true
	}
	for _, incl := range m.sanitizedOnly {
		if inclusionMatches(incl, path) || inclusionIsAncestor(path, incl) {
			return true
		}
	}
	return false
}

// Ignore reports whether path is ignored. NOTE: this reproduces Ruby's
// Mapping#ignore? which uses a raw String#start_with? (NOT a path-boundary
// check) — so an ignore entry "/a/foo" also matches "/a/foobar". The
// boundary-aware ignore filtering lives separately in the diff engine.
func (m *Mapping) Ignore(path string) bool {
	for _, ig := range m.sanitizedIgnores {
		if strings.HasPrefix(path, ig) {
			return true
		}
	}
	return false
}

func (m *Mapping) Skip(path string) bool { return m.Ignore(path) || !m.Include(path) }

// ShouldPruneDirectory reports whether an entire subtree can be skipped during
// traversal (the Find.prune optimization).
func (m *Mapping) ShouldPruneDirectory(path string) bool {
	if m.Ignore(path) {
		return true
	}
	if !m.HasInclusions() {
		return false
	}
	return !m.BidirectionalInclude(path)
}

func inclusionMatches(inclusion, path string) bool {
	if hasGlobMeta(inclusion) {
		return fnmatch(inclusion, path)
	}
	return paths.PathIsParentOrSame(inclusion, path)
}

func inclusionIsAncestor(path, inclusion string) bool {
	if hasGlobMeta(inclusion) {
		return paths.PathIsParentOrSame(path, filepath.Dir(inclusion))
	}
	return paths.PathIsParentOrSame(path, inclusion)
}

// ApplyTo returns a new single-file mapping for a changed path under src. Used
// by the watch daemon. Mirrors apply_to, including its dropping of inclusions
// (the Ruby original passes @only, which is never assigned and is therefore
// nil).
func (m *Mapping) ApplyTo(path string) *Mapping {
	rel := path
	if filepath.IsAbs(path) {
		rel = strings.TrimPrefix(path, m.sanitizedSrc+string(filepath.Separator))
	}
	return New(Attributes{
		Src:    filepath.Join(m.originalSrc, rel),
		Dest:   filepath.Join(m.originalDest, rel),
		Force:  m.force,
		Ignore: m.originalIgnores,
	})
}

// --- presentation ---

func (m *Mapping) DecoratedSrc() string  { return paths.ColorizeEnvVars(m.originalSrc) }
func (m *Mapping) DecoratedDest() string { return paths.ColorizeEnvVars(m.originalDest) }

// --- filesystem helpers (follow symlinks, matching Ruby File.* predicates) ---

func isDir(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.IsDir()
}

func isFile(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.Mode().IsRegular()
}

func exists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}
