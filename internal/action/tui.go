package action

import (
	"os"
	"sort"

	"github.com/dsaenztagarro/dotsync/internal/config"
	"github.com/dsaenztagarro/dotsync/internal/engine"
	"github.com/dsaenztagarro/dotsync/internal/model"
	"github.com/dsaenztagarro/dotsync/internal/render/tui"
)

// executeTUI is the cockpit's entry point: it takes the same snapshot the
// classic renderer would print, then hands it to the interactive screen. It is
// read-only — the caller only routes here in preview mode, so no transfer,
// backup, hook execution, or orphan cleanup can happen from this path.
func (a *Action) executeTUI() error {
	data, err := a.tuiData()
	if err != nil {
		return err
	}
	return tui.Run(data, os.Stdout)
}

// tuiData collects everything the cockpit draws. Diffs are computed only for
// the commands whose classic output has a differences section — `status`
// deliberately does not diff, so its cockpit opens on the mappings table.
func (a *Action) tuiData() (tui.Data, error) {
	sec := computeSections(a.opts)

	d := tui.Data{
		Command:    a.opts.Command,
		Direction:  a.dir.String(),
		ConfigPath: a.cfg.Path(),
		Colors:     a.colors,
		Icons:      a.icons,
		EnvVars:    a.envVarRows(),
	}
	for _, m := range a.ensureDestinations() {
		d.Notices = append(d.Notices, "created destination "+m.OriginalDest())
	}
	if sec.differences {
		if err := a.computeDiffs(); err != nil {
			return d, err
		}
		d.ShowChanges = true
		d.Changes = a.changeRows()
		d.HookCmds = a.hookPreviewCommands(a.opts.ForceHooks)
	}
	d.Mappings = a.mappingRows()
	d.Options = a.optionRows()
	return d, nil
}

// mappingRows flattens every configured mapping for display, attaching each
// mapping's change counts when a diff was computed.
func (a *Action) mappingRows() []tui.MappingRow {
	diffOf := make(map[*model.Mapping]engine.Diff, len(a.valid))
	for i, m := range a.valid {
		diffOf[m] = a.diffs[i]
	}
	rows := make([]tui.MappingRow, 0, len(a.mappings))
	for _, m := range a.mappings {
		r := tui.MappingRow{
			Src:            m.OriginalSrc(),
			Dest:           m.OriginalDest(),
			RealSrc:        m.Src(),
			RealDest:       m.Dest(),
			Force:          m.Force(),
			Only:           m.HasInclusions(),
			Ignore:         m.HasIgnores(),
			Hooks:          m.HasHooks(),
			Valid:          m.Valid(),
			OnlyPatterns:   m.OriginalOnly(),
			IgnorePatterns: m.OriginalIgnores(),
			HookCommands:   m.Hooks(),
		}
		if !r.Valid {
			if msg, ok := invalidityMessages[m.InvalidityReason()]; ok {
				r.InvalidReason, r.InvalidFix = msg[0], msg[1]
			}
		}
		if diff, ok := diffOf[m]; ok {
			r.Added, r.Modified, r.Removed = len(diff.Additions), len(diff.Modifications), len(diff.Removals)
		}
		rows = append(rows, r)
	}
	return rows
}

// changeRows lists every pending change, grouped by kind and sorted within each
// group — the order the classic differences section prints them in — with the
// pull-side orphan removals last.
func (a *Action) changeRows() []tui.ChangeRow {
	var adds, mods, rems []tui.ChangeRow
	for i, m := range a.valid {
		label := m.OriginalSrc() + " → " + m.OriginalDest()
		diff := a.diffs[i]
		for _, p := range diff.Additions {
			adds = append(adds, tui.ChangeRow{Kind: tui.KindAdded, Path: p, Mapping: label})
		}
		for _, p := range diff.Modifications {
			mods = append(mods, tui.ChangeRow{Kind: tui.KindModified, Path: p, Mapping: label})
		}
		for _, p := range diff.Removals {
			rems = append(rems, tui.ChangeRow{Kind: tui.KindRemoved, Path: p, Mapping: label})
		}
	}
	byPath := func(rows []tui.ChangeRow) {
		sort.Slice(rows, func(i, j int) bool { return rows[i].Path < rows[j].Path })
	}
	byPath(adds)
	byPath(mods)
	byPath(rems)

	rows := append(append(adds, mods...), rems...)
	if a.dir == config.Pull {
		orphans := a.orphans()
		sort.Slice(orphans, func(i, j int) bool { return orphans[i].path < orphans[j].path })
		for _, o := range orphans {
			rows = append(rows, tui.ChangeRow{
				Kind:    tui.KindRemoved,
				Path:    o.path,
				Mapping: o.mapping.OriginalSrc() + " → " + o.mapping.OriginalDest(),
				Orphan:  true,
			})
		}
	}
	return rows
}

// optionRows is the resolved-options view: the classic --show-options section
// plus the context the header cannot fit.
func (a *Action) optionRows() []tui.KeyValue {
	rows := []tui.KeyValue{
		{Key: "command", Value: a.opts.Command},
		{Key: "direction", Value: a.dir.String()},
		{Key: "config", Value: a.cfg.Path()},
		{Key: "apply", Value: boolWord(a.opts.Apply)},
		{Key: "force hooks", Value: boolWord(a.opts.ForceHooks)},
		{Key: "create dest", Value: boolWord(a.opts.CreateDest)},
	}
	if a.dir == config.Pull {
		rows = append(rows, tui.KeyValue{Key: "backups", Value: a.cfg.BackupsRoot()})
	}
	return rows
}

// envVarRows lists every environment variable the mappings reference, with the
// value it currently resolves to.
func (a *Action) envVarRows() []tui.KeyValue {
	names := a.mappingsEnvVars()
	sort.Strings(names)
	rows := make([]tui.KeyValue, 0, len(names))
	for _, n := range names {
		rows = append(rows, tui.KeyValue{Key: "$" + n, Value: os.Getenv(n)})
	}
	return rows
}

func boolWord(b bool) string {
	if b {
		return "TRUE"
	}
	return "FALSE"
}
