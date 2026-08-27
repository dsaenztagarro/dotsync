package tui

import (
	"strings"
	"testing"
)

func TestScopeOfSplitsARowIntoRootAndPath(t *testing.T) {
	cases := []struct {
		name             string
		src, dest        string
		label, cell, dst string
		ok               bool
	}{
		{
			name: "twin roots collapse to one label and the destination repeats the source",
			src:  "$XDG_CONFIG_HOME/nvim", dest: "$XDG_CONFIG_HOME_MIRROR/nvim",
			label: "config", cell: "nvim", dst: "", ok: true,
		},
		{
			name: "a destination that differs keeps its cell",
			src:  "$XDG_CONFIG_HOME/mysql/my.cnf", dest: "$XDG_CONFIG_HOME_MIRROR/mysql/my@9.5.cnf",
			label: "config", cell: "mysql/my.cnf", dst: "mysql/my@9.5.cnf", ok: true,
		},
		{
			name: "home is a scope like any other",
			src:  "$HOME/.ssh", dest: "$HOME_MIRROR/.ssh",
			label: "home", cell: ".ssh", dst: "", ok: true,
		},
		{
			name: "the root itself is marked, not blank",
			src:  "$XDG_BIN_HOME", dest: "$XDG_BIN_HOME_MIRROR",
			label: "bin", cell: rootMark, dst: "", ok: true,
		},
		{
			name: "a rootless source names both sides rather than implying symmetry",
			src:  "/opt/homebrew/var/postgresql@17/dev.conf", dest: "$XDG_CONFIG_HOME_MIRROR/postgresql/pg.conf",
			label: "abs → config", cell: "/opt/homebrew/var/postgresql@17/dev.conf", dst: "postgresql/pg.conf", ok: true,
		},
		{
			name: "roots of different kinds are both stated",
			src:  "$XDG_CONFIG_HOME/x", dest: "$XDG_DATA_HOME_MIRROR/x",
			label: "config → data", cell: "x", dst: "", ok: true,
		},
		{
			name: "an unknown variable keeps its own name, so two roots never collapse",
			src:  "$DOTFILES/zsh", dest: "$HOME_MIRROR/zsh",
			label: "DOTFILES → home", cell: "zsh", dst: "", ok: true,
		},
		{
			name: "a mapping with no variable at all has no scope",
			src:  "/etc/hosts", dest: "/backup/hosts",
			label: "abs → abs", cell: "/etc/hosts", dst: "/backup/hosts", ok: false,
		},
		{
			name: "a destination that is its own root is marked, not read as unchanged",
			src:  "$HOME/Scripts", dest: "$HOME_MIRROR",
			label: "home", cell: "Scripts", dst: rootMark, ok: true,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := scopeOf(MappingRow{Src: c.src, Dest: c.dest})
			if got.label != c.label {
				t.Errorf("label = %q, want %q", got.label, c.label)
			}
			if got.srcCell() != c.cell {
				t.Errorf("path cell = %q, want %q", got.srcCell(), c.cell)
			}
			if got.dest != c.dst {
				t.Errorf("destination cell = %q, want %q", got.dest, c.dst)
			}
			if got.ok != c.ok {
				t.Errorf("ok = %v, want %v", got.ok, c.ok)
			}
		})
	}
}

// The point of the column: the root stops being repeated on every row.
func TestScopedRowsShowTheScopeInsteadOfTheRoot(t *testing.T) {
	rows := strings.Join(listLines(sized(New(statusData()), 120, 30).View()), "\n")
	if strings.Contains(rows, "$XDG_CONFIG_HOME") || strings.Contains(rows, "$HOME_MIRROR") {
		t.Errorf("a root is still spelled out on the rows:\n%s", rows)
	}
	for _, want := range []string{"SCOPE", "config", "home", "nvim", ".ssh"} {
		if !strings.Contains(rows, want) {
			t.Errorf("rows missing %q:\n%s", want, rows)
		}
	}
}

// A destination that is just the source path under the other root says nothing,
// so it is not drawn; one that differs is.
func TestDestinationCellOnlyAppearsWhenItDiffers(t *testing.T) {
	view := sized(New(statusData()), 120, 30).View()
	if row := rowWith(t, view, "nvim"); strings.Contains(row, "→") {
		t.Errorf("an unchanged destination was drawn: %q", row)
	}
	row := rowWith(t, view, "mysql/my.cnf")
	if !strings.Contains(row, "→ mysql/my@9.5.cnf") {
		t.Errorf("a differing destination was not drawn: %q", row)
	}
}

// When nothing differs, the whole column goes.
func TestDestinationColumnDisappearsWhenNoRowDiffers(t *testing.T) {
	d := statusData()
	d.Mappings = []MappingRow{
		{Src: "$XDG_CONFIG_HOME/nvim", Dest: "$XDG_CONFIG_HOME_MIRROR/nvim", Valid: true},
		{Src: "$HOME/.ssh", Dest: "$HOME_MIRROR/.ssh", Valid: true},
	}
	p := sized(New(d), 120, 30).resolve()
	if p.table.second != 0 {
		t.Errorf("destination column = %d, want it dropped entirely", p.table.second)
	}
	if got := plain(sized(New(d), 120, 30).View()); strings.Contains(got, "DESTINATION") {
		t.Errorf("destination header survived an all-identical table:\n%s", got)
	}
}

// The column has to earn its width, like the flag gutter.
func TestScopeColumnIsSkippedWhenItWouldFactorNothingOut(t *testing.T) {
	d := statusData()
	d.Mappings = []MappingRow{
		{Src: "/etc/hosts", Dest: "/backup/hosts", RealSrc: "/etc/hosts", RealDest: "/backup/hosts", Valid: true},
		{Src: "/etc/motd", Dest: "/backup/motd", RealSrc: "/etc/motd", RealDest: "/backup/motd", Valid: true},
	}
	m := sized(New(d), 120, 30)
	if m.resolve().scoped {
		t.Fatal("scoped a table whose rows have no roots")
	}
	rows := strings.Join(listLines(m.View()), "\n")
	if !strings.Contains(rows, "/etc/hosts") || !strings.Contains(rows, "/backup/hosts") {
		t.Errorf("unscoped rows lost their full paths:\n%s", rows)
	}
}

// Most rows have no second line to fold, so a narrow terminal fits far more of
// them than the unscoped layout could.
func TestFoldedScopedRowsStayOnOneLineWhenNothingDiffers(t *testing.T) {
	m := sized(New(statusData()), 56, 20)
	p := m.resolve()
	if !p.table.folded {
		t.Fatalf("expected the folded layout at 56 columns (table=%d)", p.table.total())
	}
	idxs := m.visible()
	for i, idx := range idxs {
		want := 1
		if scopeOf(m.data.Mappings[idx]).dest != "" {
			want = 2
		}
		if got := m.rowLines(p, i); got != want {
			t.Errorf("row %d (%s) takes %d lines, want %d", i, m.data.Mappings[idx].Src, got, want)
		}
	}
	rows := listLines(m.View())
	if !strings.Contains(strings.Join(rows, "\n"), "→ mysql/my@9.5.cnf") {
		t.Errorf("the differing destination lost its folded line:\n%s", strings.Join(rows, "\n"))
	}
}

// Filtering matches what the config says, not only what the row draws.
func TestFilterStillMatchesTheHiddenRoot(t *testing.T) {
	m := press(t, sized(New(statusData()), 120, 30), "/", "XDG_CONFIG_HOME")
	if got := len(m.visible()); got != 3 {
		t.Errorf("%d rows matched the hidden root, want 3", got)
	}
}

func TestLegendExplainsTheScopeColumn(t *testing.T) {
	view := plain(press(t, sized(New(statusData()), 160, 40), "l").View())
	for _, want := range []string{"scope", "different roots", "same path under its own root"} {
		if !strings.Contains(view, want) {
			t.Errorf("legend missing %q in:\n%s", want, view)
		}
	}
}
