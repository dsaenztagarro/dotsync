package tui

import (
	"strings"

	"github.com/dsaenztagarro/dotsync/internal/paths"
)

// A mapping's two paths are almost always rooted in the same environment
// variable — `$XDG_CONFIG_HOME/nvim → $XDG_CONFIG_HOME_MIRROR/nvim` — so the
// root is table-level information repeated on every row, and the destination is
// usually the source path again. This file lifts the root out into a scope and
// keeps the destination only when it actually differs.

// knownRoots maps the variables dotsync's own shorthands are built on to the
// short name shown in the scope column. Any other variable keeps its name, so
// two different roots can never collapse into one label.
var knownRoots = map[string]string{
	"HOME":            "home",
	"XDG_CONFIG_HOME": "config",
	"XDG_DATA_HOME":   "data",
	"XDG_CACHE_HOME":  "cache",
	"XDG_BIN_HOME":    "bin",
}

// rootlessScope labels a path that is not rooted in a variable at all.
const rootlessScope = "abs"

// rootMark stands in for a path that IS its root, with nothing beneath it.
const rootMark = "·"

// rowScope is a mapping row rewritten as "which root, which path beneath it".
type rowScope struct {
	label string // "config", "home", "abs → config", "DOTFILES"
	src   string // the path beneath the source root, or the whole path when rootless
	dest  string // the path beneath the destination root; empty when it repeats src
	ok    bool   // at least one side is rooted in a variable
}

// scopeOf splits a mapping row into its scope label and the paths beneath it.
func scopeOf(r MappingRow) rowScope {
	srcVar, srcTail := splitRoot(r.Src)
	destVar, destTail := splitRoot(r.Dest)

	s := rowScope{
		src: srcTail,
		ok:  srcVar != "" || destVar != "",
	}
	// A single label is only honest when both sides share a root, mirror
	// suffix aside; otherwise the row says where it comes from and where it
	// goes, and `abs` names a side that has no root at all.
	switch {
	case srcVar != "" && destVar != "" && baseRoot(srcVar) == baseRoot(destVar):
		s.label = scopeLabel(srcVar)
	default:
		s.label = scopeLabel(srcVar) + " → " + scopeLabel(destVar)
	}
	// The destination earns a cell only when it is not the source path again.
	// An empty cell means "the same path"; a destination that IS its root is
	// marked, so it can never be read as unchanged.
	if !(srcVar != "" && destVar != "" && srcTail == destTail) {
		s.dest = orRootMark(destTail)
	}
	return s
}

// splitRoot separates a leading `$VAR` from the path beneath it. A path that is
// exactly its root has an empty tail; a path with no variable root returns no
// variable and the whole path.
func splitRoot(p string) (variable, tail string) {
	if !strings.HasPrefix(p, "$") {
		return "", p
	}
	spans := paths.EnvVarSpans(p)
	if len(spans) == 0 || spans[0][0] != 0 {
		return "", p
	}
	variable = p[1:spans[0][1]]
	return variable, strings.TrimPrefix(p[spans[0][1]:], "/")
}

// baseRoot is a variable's name without the mirror suffix, which is what makes
// `$XDG_CONFIG_HOME` and `$XDG_CONFIG_HOME_MIRROR` two ends of one scope.
func baseRoot(variable string) string { return strings.TrimSuffix(variable, "_MIRROR") }

// scopeLabel names a root: the short name for the variables dotsync's own
// shorthands use, the variable's own name for anything else, and `abs` for a
// path that is not rooted in a variable.
func scopeLabel(variable string) string {
	if variable == "" {
		return rootlessScope
	}
	if name, ok := knownRoots[baseRoot(variable)]; ok {
		return name
	}
	return baseRoot(variable)
}

// display returns the cell text for a path beneath a root, marking the root
// itself rather than rendering an empty cell.
func (s rowScope) srcCell() string { return orRootMark(s.src) }

func orRootMark(tail string) string {
	if tail == "" {
		return rootMark
	}
	return tail
}
