// Package engine implements dotsync's directory diffing — the read side of a
// sync. Differ is a faithful port of Ruby's Dotsync::DirectoryDiffer, including
// its performance optimizations: a source index built during a single source
// walk (O(1) force-mode removal lookups), subtree pruning during traversal, and
// size-first file comparison.
package engine

import (
	"io/fs"
	"path/filepath"
	"strings"

	"github.com/dsaenztagarro/dotsync/internal/fsutil"
	"github.com/dsaenztagarro/dotsync/internal/model"
)

// ModPair carries the concrete (sanitized, absolute) source and destination of
// a modified file, used later for content diffs. Mirrors the Ruby
// modification_pairs entries.
type ModPair struct {
	RelPath string
	Src     string
	Dest    string
}

// Diff is the set of changes needed to sync a destination with its source.
// Additions, Modifications, and Removals are absolute paths in the mapping's
// ORIGINAL (unexpanded) destination space, matching the Ruby Diff. RemovalRelPaths
// carries the relative removal paths so FileTransfer can act without rescanning.
type Diff struct {
	Additions         []string
	Modifications     []string
	Removals          []string
	ModificationPairs []ModPair
	RemovalRelPaths   []string
}

// Any reports whether there is anything to transfer.
func (d Diff) Any() bool {
	return len(d.Additions) > 0 || len(d.Modifications) > 0 || len(d.Removals) > 0
}

// Empty is the negation of Any.
func (d Diff) Empty() bool { return !d.Any() }

// Differ computes the Diff for a single mapping.
type Differ struct {
	m *model.Mapping
}

// New returns a Differ for the mapping.
func New(m *model.Mapping) *Differ { return &Differ{m: m} }

// Diff dispatches on the mapping's shape, mirroring DirectoryDiffer#diff.
func (dr *Differ) Diff() (Diff, error) {
	switch {
	case dr.m.Directories():
		return dr.diffDirectories()
	case dr.m.Files():
		return dr.diffFiles()
	default:
		return Diff{}, nil
	}
}

func (dr *Differ) diffDirectories() (Diff, error) {
	m := dr.m
	src := m.Src()   // sanitized
	dest := m.Dest() // sanitized

	var additions, modifications, removals []string
	var modPairs []ModPair
	sourceIndex := make(map[string]bool)

	// Single source walk: build the index AND collect additions/modifications,
	// pruning subtrees outside the `only` filter.
	err := filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !m.BidirectionalInclude(path) {
			if d.IsDir() {
				return fs.SkipDir
			}
			return nil
		}
		sourceIndex[path] = true

		rel := relPath(src, path)
		destPath := filepath.Join(dest, rel)
		switch {
		case !fsutil.Exists(destPath):
			additions = append(additions, rel)
		case fsutil.IsFile(path) && fsutil.IsFile(destPath):
			differ, derr := fsutil.FilesDiffer(path, destPath)
			if derr != nil {
				return derr
			}
			if differ {
				modifications = append(modifications, rel)
				modPairs = append(modPairs, ModPair{RelPath: rel, Src: path, Dest: destPath})
			}
		}
		return nil
	})
	if err != nil {
		return Diff{}, err
	}

	// Force mode: a second walk of the destination finds files with no source
	// counterpart, using the in-memory source index (O(1)) rather than disk I/O.
	if m.Force() {
		err = filepath.WalkDir(dest, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			rel := relPath(dest, path)
			if rel == "" {
				return nil // skip the destination root
			}
			srcPath := filepath.Join(src, rel)
			if d.IsDir() && m.ShouldPruneDirectory(srcPath) {
				return fs.SkipDir
			}
			if m.Skip(srcPath) {
				return nil // skip file; for a dir, keep descending
			}
			if !sourceIndex[srcPath] {
				removals = append(removals, rel)
			}
			return nil
		})
		if err != nil {
			return Diff{}, err
		}
	}

	// Ignore filtering (raw entries, boundary-aware) then relative -> absolute
	// in ORIGINAL destination space.
	rawIgnores := m.OriginalIgnores()
	origDest := m.OriginalDest()

	filteredMods := filterIgnores(modifications, rawIgnores)
	modPairs = selectPairs(modPairs, filteredMods)
	filteredRemovals := filterIgnores(removals, rawIgnores)

	return Diff{
		Additions:         relToAbs(filterIgnores(additions, rawIgnores), origDest),
		Modifications:     relToAbs(filteredMods, origDest),
		Removals:          relToAbs(filteredRemovals, origDest),
		ModificationPairs: modPairs,
		RemovalRelPaths:   filteredRemovals,
	}, nil
}

func (dr *Differ) diffFiles() (Diff, error) {
	m := dr.m
	if m.FilePresentInSrcOnly() {
		return Diff{Additions: []string{m.OriginalDest()}}, nil
	}
	changed, err := m.FileChanged()
	if err != nil {
		return Diff{}, err
	}
	if changed {
		return Diff{
			Modifications: []string{m.OriginalDest()},
			ModificationPairs: []ModPair{{
				RelPath: filepath.Base(m.OriginalDest()),
				Src:     m.Src(),
				Dest:    m.Dest(),
			}},
		}, nil
	}
	return Diff{}, nil
}

// relPath returns path relative to base by stripping the base prefix and a
// leading separator, matching the Ruby `sub(/^base\/?/, "")` (root -> "").
func relPath(base, path string) string {
	rel := strings.TrimPrefix(path, base)
	return strings.TrimPrefix(rel, string(filepath.Separator))
}

// filterIgnores rejects relative paths that equal, or are inside, a raw ignore
// entry. Mirrors DirectoryDiffer#filter_ignores, which is boundary-aware and
// distinct from Mapping#ignore?'s raw-prefix check.
func filterIgnores(rels, rawIgnores []string) []string {
	if len(rawIgnores) == 0 {
		return rels
	}
	out := rels[:0:0]
	for _, rel := range rels {
		if !ignored(rel, rawIgnores) {
			out = append(out, rel)
		}
	}
	return out
}

func ignored(rel string, rawIgnores []string) bool {
	for _, ig := range rawIgnores {
		if rel == ig || strings.HasPrefix(rel, ig+"/") {
			return true
		}
	}
	return false
}

// selectPairs keeps only the modification pairs whose RelPath survived ignore
// filtering.
func selectPairs(pairs []ModPair, keptRels []string) []ModPair {
	if len(pairs) == 0 {
		return pairs
	}
	kept := make(map[string]bool, len(keptRels))
	for _, r := range keptRels {
		kept[r] = true
	}
	out := pairs[:0:0]
	for _, p := range pairs {
		if kept[p.RelPath] {
			out = append(out, p)
		}
	}
	return out
}

func relToAbs(rels []string, base string) []string {
	if len(rels) == 0 {
		return nil
	}
	out := make([]string, len(rels))
	for i, rel := range rels {
		out[i] = filepath.Join(base, rel)
	}
	return out
}
