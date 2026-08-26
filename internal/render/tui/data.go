// Package tui renders dotsync's read-only preview surfaces as a full-screen
// Bubble Tea cockpit: the mappings table behind `dotsync status` and the
// changes list behind `diff`/`push`/`pull` in preview mode.
//
// It is the third consumer of the engine's data, alongside the classic line
// renderer and the parity harness — it renders, the engine does not. Everything
// it draws arrives as a Data value built by the action layer from the same
// Mapping and Diff values the classic renderer consumes; no type in this
// package reaches back into the filesystem, and nothing here can mutate it.
package tui

import (
	"fmt"
	"strings"

	"github.com/dsaenztagarro/dotsync/internal/render"
)

// Kind classifies a change row: a created, modified, or removed file.
type Kind int

// The change kinds, ordered the way the classic renderer lists them.
const (
	KindAdded Kind = iota
	KindModified
	KindRemoved
)

// MappingRow is one configured mapping, flattened for display. Src/Dest keep
// the original `$VAR` form the user wrote; RealSrc/RealDest are the resolved
// absolute paths.
type MappingRow struct {
	Src      string
	Dest     string
	RealSrc  string
	RealDest string

	Force  bool
	Only   bool
	Ignore bool
	Hooks  bool
	Valid  bool

	InvalidReason string
	InvalidFix    string

	OnlyPatterns   []string
	IgnorePatterns []string
	HookCommands   []string

	// Per-mapping change counts, zero unless the command computed a diff.
	Added    int
	Modified int
	Removed  int
}

// Label is the mapping's one-line identity, used as a change row's provenance.
func (r MappingRow) Label() string { return r.Src + " -> " + r.Dest }

// Changes is the mapping's total number of pending changes.
func (r MappingRow) Changes() int { return r.Added + r.Modified + r.Removed }

// ChangeRow is one pending file change in the destination space.
type ChangeRow struct {
	Kind    Kind
	Path    string
	Mapping string // the owning mapping's Label
	Orphan  bool   // a pull-side orphan removal rather than a diff removal
}

// KeyValue is a labeled line in the Config tab and the detail pane.
type KeyValue struct {
	Key   string
	Value string
}

// Data is everything the cockpit draws: a snapshot, computed before the program
// starts and never refreshed while it runs.
type Data struct {
	Command    string // "status", "diff", "push", "pull"
	Direction  string // "push" or "pull"
	ConfigPath string

	Mappings []MappingRow
	Changes  []ChangeRow
	// ShowChanges reports whether this command computed a diff. `status` does
	// not, so its cockpit opens on Mappings and has no Changes tab.
	ShowChanges bool

	Options  []KeyValue
	EnvVars  []KeyValue
	HookCmds []string
	Notices  []string // e.g. destinations created by --create-dest

	Colors render.Colors
	Icons  render.Icons
}

// ValidCount and InvalidCount count mappings by validity.
func (d Data) ValidCount() int {
	n := 0
	for _, m := range d.Mappings {
		if m.Valid {
			n++
		}
	}
	return n
}

// InvalidCount is the complement of ValidCount.
func (d Data) InvalidCount() int { return len(d.Mappings) - d.ValidCount() }

// CountByKind counts change rows of one kind.
func (d Data) CountByKind(k Kind) int {
	n := 0
	for _, c := range d.Changes {
		if c.Kind == k {
			n++
		}
	}
	return n
}

// Summary is the single line printed to stdout when the cockpit exits. The
// alt-screen is restored on quit, so this is all that survives in scrollback —
// it has to carry the takeaway on its own.
func (d Data) Summary() string {
	var b strings.Builder
	fmt.Fprintf(&b, "%s: %d mapping%s, %d valid", d.Command, len(d.Mappings), plural(len(d.Mappings)), d.ValidCount())
	if n := d.InvalidCount(); n > 0 {
		fmt.Fprintf(&b, ", %d invalid", n)
	}
	if d.ShowChanges {
		if len(d.Changes) == 0 {
			b.WriteString(" · no differences")
		} else {
			fmt.Fprintf(&b, " · %d change%s: %d added, %d modified, %d removed",
				len(d.Changes), plural(len(d.Changes)),
				d.CountByKind(KindAdded), d.CountByKind(KindModified), d.CountByKind(KindRemoved))
		}
	}
	return b.String()
}

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}
