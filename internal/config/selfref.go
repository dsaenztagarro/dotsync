package config

import (
	"github.com/dsaenztagarro/dotsync/internal/model"
	"github.com/dsaenztagarro/dotsync/internal/paths"
)

// A configuration can be both an input to a run and a payload of it: the
// mappings that decide what gets copied are themselves copied. That is legal
// and documented, but it has consequences a preview cannot show, and which
// side of the mapping the config sits on decides which one bites.
//
// On the destination side the run overwrites the config it was planned from,
// so an incoming rule is delivered by a run governed by the previous rules and
// governs nothing until the run after that. On the source side the run ships
// the live config outward, so an edit made to the copy at the far end is
// reverted without ever being mentioned.
//
// SelfReferences reports rather than refuses. A directory mapping legitimately
// covers a tree that happens to contain the config, so refusing would break
// working setups, and changing which files get written would diverge from the
// Ruby oracle the parity harness compares against. `source` is the way out,
// and the diagnostic says so.

// Role says how a config file participates in a transfer.
type Role int

const (
	// Overwritten: the config is on the destination side, so the run rewrites it.
	Overwritten Role = iota
	// Propagated: the config is on the source side, so the run copies it out
	// over whatever stands at the far end.
	Propagated
)

// SelfReference is one config file that one mapping's transfer would move.
type SelfReference struct {
	ConfigFile string // the provenance file at stake (host, sourced, or included)
	Mapping    *model.Mapping
	Role       Role
}

// SelfReferences returns every (config file, mapping) pair where applying the
// mapping would move a file that produced the configuration. Invalid mappings
// are skipped: they never transfer anything.
//
// A file on the destination side is reported as Overwritten; otherwise a file
// on the source side is reported as Propagated. Both cannot apply at once —
// a mapping whose source and destination overlap is invalid.
func SelfReferences(mappings []*model.Mapping, prov Provenance) []SelfReference {
	var out []SelfReference
	for _, f := range prov.Files() {
		path := paths.SanitizePath(f)
		for _, m := range mappings {
			if !m.Valid() {
				continue
			}
			switch {
			case transfers(m, m.Dest(), path):
				out = append(out, SelfReference{ConfigFile: f, Mapping: m, Role: Overwritten})
			case transfers(m, m.Src(), path):
				out = append(out, SelfReference{ConfigFile: f, Mapping: m, Role: Propagated})
			}
		}
	}
	return out
}

// transfers reports whether path takes part in m's transfer on the given side.
// A path must be that side's root or inside it, and must survive the mapping's
// own filters.
//
// Skip is evaluated against the config path as-is, which is sound on either
// side because Mapping expands every `only` and `ignore` entry against both
// the source and the destination when it is built.
func transfers(m *model.Mapping, side, path string) bool {
	if !paths.PathIsParentOrSame(side, path) {
		return false
	}
	return !m.Skip(path)
}
