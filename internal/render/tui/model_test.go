package tui

import (
	"regexp"
	"strings"
	"testing"
	"unicode/utf8"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/dsaenztagarro/dotsync/internal/render"
)

// The cockpit is exercised the way a terminal drives it: real tea.Msg values
// into the real model, assertions on the real View. Only the escape sequences
// are stripped, so the assertions read like what a user sees.

var ansiPattern = regexp.MustCompile("\x1b\\[[0-9;]*m")

func plain(s string) string { return ansiPattern.ReplaceAllString(s, "") }

func lines(s string) []string { return strings.Split(plain(s), "\n") }

// listLines returns the list side of each rendered line, cutting a side-by-side
// panel off, so assertions about rows are not satisfied by text that happens to
// appear in the detail pane.
func listLines(view string) []string {
	var out []string
	for _, l := range lines(view) {
		if i := strings.IndexAny(l, "│╭╰"); i >= 0 {
			l = l[:i]
		}
		out = append(out, strings.TrimRight(l, " "))
	}
	return out
}

// lineWith returns the first rendered line containing want.
func lineWith(t *testing.T, view, want string) string {
	t.Helper()
	for _, l := range lines(view) {
		if strings.Contains(l, want) {
			return l
		}
	}
	t.Fatalf("no line containing %q in view:\n%s", want, plain(view))
	return ""
}

// rowWith returns the first list row containing want, ignoring the panel.
func rowWith(t *testing.T, view, want string) string {
	t.Helper()
	for _, l := range listLines(view) {
		if strings.Contains(l, want) {
			return l
		}
	}
	t.Fatalf("no row containing %q in view:\n%s", want, plain(view))
	return ""
}

func keyMsg(k string) tea.KeyMsg {
	switch k {
	case "esc":
		return tea.KeyMsg{Type: tea.KeyEsc}
	case "enter":
		return tea.KeyMsg{Type: tea.KeyEnter}
	case "tab":
		return tea.KeyMsg{Type: tea.KeyTab}
	case "shift+tab":
		return tea.KeyMsg{Type: tea.KeyShiftTab}
	case "up":
		return tea.KeyMsg{Type: tea.KeyUp}
	case "down":
		return tea.KeyMsg{Type: tea.KeyDown}
	case "ctrl+c":
		return tea.KeyMsg{Type: tea.KeyCtrlC}
	case "backspace":
		return tea.KeyMsg{Type: tea.KeyBackspace}
	default:
		return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(k)}
	}
}

// press sends each key in turn and returns the resulting model.
func press(t *testing.T, m Model, keys ...string) Model {
	t.Helper()
	for _, k := range keys {
		next, _ := m.Update(keyMsg(k))
		m = next.(Model)
	}
	return m
}

func sized(m Model, w, h int) Model {
	next, _ := m.Update(tea.WindowSizeMsg{Width: w, Height: h})
	return next.(Model)
}

// statusData mirrors what `dotsync status` hands the cockpit: mappings, no diff.
func statusData() Data {
	return Data{
		Command:    "status",
		Direction:  "push",
		ConfigPath: "~/.config/dotsync.toml",
		Mappings: []MappingRow{
			{
				Src: "$XDG_CONFIG_HOME/nvim", Dest: "$XDG_CONFIG_HOME_MIRROR/nvim",
				RealSrc: "/home/d/.config/nvim", RealDest: "/home/d/mirror/nvim",
				Force: true, Ignore: true, Valid: true,
				IgnorePatterns: []string{"*.swp"},
			},
			{
				Src: "$HOME/.ssh", Dest: "$HOME_MIRROR/.ssh",
				RealSrc: "/home/d/.ssh", RealDest: "/home/d/mirror/.ssh",
				Only: true, Hooks: true, Valid: true,
				OnlyPatterns: []string{"config", "config.d/*"},
				HookCommands: []string{"chmod 600 {files}"},
			},
			{
				Src: "$XDG_CONFIG_HOME/mysql/my.cnf", Dest: "$XDG_CONFIG_HOME_MIRROR/mysql/my@9.5.cnf",
				RealSrc: "/home/d/.config/mysql/my.cnf", RealDest: "/home/d/mirror/mysql/my@9.5.cnf",
				Valid: true,
			},
			{
				Src: "$XDG_CONFIG_HOME/cabal/config", Dest: "$XDG_CONFIG_HOME_MIRROR/cabal/config",
				RealSrc: "/home/d/.config/cabal/config", RealDest: "/home/d/mirror/cabal/config",
				Valid: false, InvalidReason: "destination directory does not exist", InvalidFix: "--create-dest",
			},
		},
		Options: []KeyValue{{Key: "apply", Value: "FALSE"}},
		EnvVars: []KeyValue{{Key: "$XDG_CONFIG_HOME", Value: "/home/d/.config"}},
		Colors:  render.DefaultColors(),
		Icons:   render.DefaultIcons(),
	}
}

// diffData mirrors `dotsync diff`: the same mappings plus pending changes.
func diffData() Data {
	d := statusData()
	d.Command = "diff"
	d.ShowChanges = true
	d.Mappings[0].Added, d.Mappings[0].Modified = 2, 1
	d.Changes = []ChangeRow{
		{Kind: KindAdded, Path: "/home/d/mirror/nvim/init.lua", Mapping: "$XDG_CONFIG_HOME/nvim → $XDG_CONFIG_HOME_MIRROR/nvim"},
		{Kind: KindAdded, Path: "/home/d/mirror/nvim/lua/plugins.lua", Mapping: "$XDG_CONFIG_HOME/nvim → $XDG_CONFIG_HOME_MIRROR/nvim"},
		{Kind: KindModified, Path: "/home/d/mirror/nvim/lazy-lock.json", Mapping: "$XDG_CONFIG_HOME/nvim → $XDG_CONFIG_HOME_MIRROR/nvim"},
		{Kind: KindRemoved, Path: "/home/d/mirror/nvim/old.lua", Mapping: "$XDG_CONFIG_HOME/nvim → $XDG_CONFIG_HOME_MIRROR/nvim", Orphan: true},
	}
	d.HookCmds = []string{"chmod 600 /home/d/mirror/.ssh/config"}
	return d
}

func TestHeaderCarriesCommandConfigAndCounts(t *testing.T) {
	view := sized(New(statusData()), 100, 30).View()
	head := lines(view)[0]
	for _, want := range []string{"dotsync status", "~/.config/dotsync.toml", "PUSH"} {
		if !strings.Contains(head, want) {
			t.Errorf("header %q missing %q", head, want)
		}
	}
	counts := lines(view)[1]
	for _, want := range []string{"4 mappings", "3 valid", "1 invalid"} {
		if !strings.Contains(counts, want) {
			t.Errorf("counts line %q missing %q", counts, want)
		}
	}
}

// The unaligned classic output is what this screen replaces: every path has to
// start in the same column no matter which flags or scope its row carries.
func TestMappingPathsShareOneColumn(t *testing.T) {
	m := sized(New(statusData()), 100, 30)
	p := m.resolve()
	want := p.table.gutter + p.table.lead + 1 + p.table.scope + 2

	var found int
	for _, l := range listLines(m.View()) {
		for _, path := range []string{"nvim", ".ssh", "mysql/my.cnf", "cabal/config"} {
			if i := strings.Index(l, path); i >= 0 {
				if col := utf8.RuneCountInString(l[:i]); col != want {
					t.Errorf("%q starts at column %d, want %d in %q", path, col, want, l)
				}
				found++
				break
			}
		}
	}
	if found != 4 {
		t.Errorf("found %d path cells, want 4", found)
	}
}

func TestFlagGutterKeepsOneColumnPerFlag(t *testing.T) {
	view := sized(New(statusData()), 100, 30).View()
	forceRow := []rune(rowWith(t, view, "nvim")) // force + ignore
	onlyRow := []rune(rowWith(t, view, ".ssh"))  // only + hooks

	const marker = 2 // the two-cell cursor gutter
	slots := []struct {
		row   []rune
		glyph rune
		col   int
	}{
		{forceRow, '!', marker},     // force: slot 1
		{onlyRow, '>', marker + 2},  // only: slot 2
		{forceRow, 'x', marker + 4}, // ignore: slot 3
		{onlyRow, '@', marker + 6},  // hooks: slot 4
	}
	for _, s := range slots {
		if got := runeIndex(s.row, s.glyph); got != s.col {
			t.Errorf("glyph %q at column %d, want %d in %q", s.glyph, got, s.col, string(s.row))
		}
	}
}

func runeIndex(row []rune, want rune) int {
	for i, r := range row {
		if r == want {
			return i
		}
	}
	return -1
}

func TestSelectedMappingDetailShowsResolvedPathsAndFilters(t *testing.T) {
	m := sized(New(statusData()), 100, 30)
	view := press(t, m, "j").View() // the .ssh mapping
	for _, want := range []string{"/home/d/.ssh", "/home/d/mirror/.ssh", "config.d/*", "chmod 600 {files}"} {
		if !strings.Contains(plain(view), want) {
			t.Errorf("detail pane missing %q in:\n%s", want, plain(view))
		}
	}
}

func TestInvalidMappingExplainsItselfInTheDetailPane(t *testing.T) {
	m := sized(New(statusData()), 160, 30) // wide enough for the panel to spell it out
	view := press(t, m, "G").View()        // last row is the invalid one
	if !strings.Contains(plain(view), "destination directory does not exist") {
		t.Errorf("expected the invalidity reason in:\n%s", plain(view))
	}
	if !strings.Contains(plain(view), "--create-dest") {
		t.Errorf("expected the suggested fix in:\n%s", plain(view))
	}
}

func TestFilterNarrowsRowsAndEscapeRestoresThem(t *testing.T) {
	m := sized(New(statusData()), 100, 30)
	m = press(t, m, "/", "ssh")
	view := strings.Join(listLines(m.View()), "\n")
	if !strings.Contains(view, ".ssh") {
		t.Errorf("filtered view lost the match:\n%s", view)
	}
	if strings.Contains(view, "nvim") {
		t.Errorf("filtered view kept a non-match:\n%s", view)
	}

	m = press(t, m, "esc")
	if got := strings.Join(listLines(m.View()), "\n"); !strings.Contains(got, "nvim") {
		t.Errorf("esc did not restore the rows:\n%s", got)
	}
}

func TestFilterWithNoMatchesExplainsItself(t *testing.T) {
	m := sized(New(statusData()), 100, 30)
	m = press(t, m, "/", "zzz")
	if got := plain(m.View()); !strings.Contains(got, "No rows match the filter") {
		t.Errorf("expected an empty-filter message in:\n%s", got)
	}
}

func TestCursorStaysInsideTheFilteredRowSet(t *testing.T) {
	m := sized(New(statusData()), 100, 30)
	m = press(t, m, "G")        // cursor on the last row
	m = press(t, m, "/", "ssh") // one row left
	if got := m.cursor[m.tab()]; got != 0 {
		t.Errorf("cursor = %d, want it clamped to 0", got)
	}
}

func TestStatusHasNoChangesTabAndDiffOpensOnIt(t *testing.T) {
	status := sized(New(statusData()), 100, 30)
	if got := plain(status.View()); strings.Contains(got, "Changes") {
		t.Errorf("status should not offer a Changes tab:\n%s", got)
	}
	if status.tab() != tabMappings {
		t.Errorf("status opened on tab %v, want Mappings", status.tab())
	}

	diff := sized(New(diffData()), 100, 30)
	if diff.tab() != tabChanges {
		t.Errorf("diff opened on tab %v, want Changes", diff.tab())
	}
}

func TestChangesTabListsAdditionsModificationsRemovals(t *testing.T) {
	view := plain(sized(New(diffData()), 100, 30).View())
	for _, want := range []string{"+ /home/d/mirror/nvim/init.lua", "~ /home/d/mirror/nvim/lazy-lock.json", "- /home/d/mirror/nvim/old.lua"} {
		if !strings.Contains(view, want) {
			t.Errorf("changes view missing %q in:\n%s", want, view)
		}
	}
	if !strings.Contains(view, "(orphan)") {
		t.Errorf("orphan removal not tagged in:\n%s", view)
	}
	if !strings.Contains(view, "run with --apply to sync") {
		t.Errorf("preview hint missing in:\n%s", view)
	}
}

func TestPerMappingChangeCountsAppearOnTheMappingsTab(t *testing.T) {
	m := sized(New(diffData()), 100, 30)
	view := press(t, m, "tab").View() // Changes -> Mappings
	row := rowWith(t, view, "nvim")
	if !strings.Contains(row, "+2") || !strings.Contains(row, "~1") {
		t.Errorf("mapping row missing its change counts: %q", row)
	}
}

func TestTabCyclesThroughEveryTab(t *testing.T) {
	m := sized(New(diffData()), 100, 30)
	want := []tab{tabMappings, tabConfig, tabChanges}
	for i, w := range want {
		m = press(t, m, "tab")
		if m.tab() != w {
			t.Fatalf("after %d tabs: got %v, want %v", i+1, m.tab(), w)
		}
	}
	if m = press(t, m, "shift+tab"); m.tab() != tabConfig {
		t.Errorf("shift+tab went to %v, want Config", m.tab())
	}
}

func TestConfigTabShowsOptionsEnvAndHooks(t *testing.T) {
	m := sized(New(diffData()), 100, 30)
	view := plain(press(t, m, "tab", "tab").View()) // Changes -> Mappings -> Config
	for _, want := range []string{"OPTIONS", "apply", "ENVIRONMENT", "$XDG_CONFIG_HOME", "HOOKS TO RUN", "chmod 600"} {
		if !strings.Contains(view, want) {
			t.Errorf("config tab missing %q in:\n%s", want, view)
		}
	}
}

func TestLegendExplainsEveryFlag(t *testing.T) {
	m := sized(New(statusData()), 100, 30)
	view := plain(press(t, m, "l").View())
	for _, want := range []string{"LEGEND", "force", "only", "ignore", "hooks", "invalid"} {
		if !strings.Contains(view, want) {
			t.Errorf("legend missing %q in:\n%s", want, view)
		}
	}
	if view := plain(press(t, m, "l", "l").View()); strings.Contains(view, "LEGEND") {
		t.Errorf("legend did not toggle off:\n%s", view)
	}
}

func TestDetailPaneToggles(t *testing.T) {
	m := sized(New(statusData()), 100, 30)
	if !strings.Contains(plain(m.View()), "/home/d/.config/nvim") {
		t.Fatal("expected the detail pane on by default")
	}
	if got := plain(press(t, m, "d").View()); strings.Contains(got, "/home/d/.config/nvim") {
		t.Errorf("d did not hide the detail pane:\n%s", got)
	}
}

func TestNarrowTerminalTruncatesInsteadOfWrapping(t *testing.T) {
	view := sized(New(statusData()), 46, 20).View()
	for _, l := range lines(view) {
		if w := len([]rune(l)); w > 46 {
			t.Errorf("line overflows a 46-column terminal (%d): %q", w, l)
		}
	}
	if !strings.Contains(plain(view), ellipsis) {
		t.Errorf("expected truncation in a narrow view:\n%s", plain(view))
	}
}

func TestOverflowingListKeepsThePositionIndicator(t *testing.T) {
	d := statusData()
	for i := 0; i < 30; i++ {
		d.Mappings = append(d.Mappings, MappingRow{Src: "$HOME/f", Dest: "$HOME_MIRROR/f", Valid: true})
	}
	m := sized(New(d), 100, 24)
	if got := plain(m.View()); !strings.Contains(got, "row 1 of 34") {
		t.Errorf("expected a position indicator when rows overflow:\n%s", got)
	}
	if got := plain(press(t, m, "G").View()); !strings.Contains(got, "row 34 of 34") {
		t.Errorf("indicator did not follow the cursor:\n%s", got)
	}
}

// On a terminal too short for both, the detail pane yields so the list stays
// on screen.
func TestShortTerminalDropsTheDetailPaneBeforeTheRows(t *testing.T) {
	view := plain(sized(New(statusData()), 100, 10).View())
	if !strings.Contains(view, ".ssh") {
		t.Errorf("rows squeezed off a short screen:\n%s", view)
	}
	if strings.Contains(view, "the destination is overwritten") {
		t.Errorf("detail pane kept its space on a short screen:\n%s", view)
	}
}

func TestEmptyStates(t *testing.T) {
	empty := statusData()
	empty.Mappings = nil
	if got := plain(sized(New(empty), 100, 30).View()); !strings.Contains(got, "No mappings configured") {
		t.Errorf("expected an empty-mappings message in:\n%s", got)
	}

	synced := diffData()
	synced.Changes = nil
	if got := plain(sized(New(synced), 100, 30).View()); !strings.Contains(got, "Everything is in sync") {
		t.Errorf("expected an in-sync message in:\n%s", got)
	}
}

func TestQuitKeysEndTheProgram(t *testing.T) {
	for _, key := range []string{"q", "esc", "ctrl+c"} {
		next, cmd := New(statusData()).Update(keyMsg(key))
		m := next.(Model)
		if !m.Quitting() {
			t.Errorf("%q did not set quitting", key)
		}
		if cmd == nil {
			t.Fatalf("%q returned no command", key)
		}
		if _, ok := cmd().(tea.QuitMsg); !ok {
			t.Errorf("%q did not return tea.Quit", key)
		}
	}
}

func TestFilterModeSwallowsNavigationKeys(t *testing.T) {
	m := sized(New(statusData()), 100, 30)
	m = press(t, m, "/", "j") // 'j' is text, not a movement, while filtering
	if got := m.filter.Value(); got != "j" {
		t.Errorf("filter value = %q, want %q", got, "j")
	}
	if got := m.cursor[m.tab()]; got != 0 {
		t.Errorf("cursor moved while filtering: %d", got)
	}
}

func TestCustomIconsAndColorsAreHonored(t *testing.T) {
	d := statusData()
	d.Icons.Force = "󰓾"
	d.Icons.Invalid = "" // a blank glyph removes the column
	view := plain(sized(New(d), 100, 30).View())
	if !strings.Contains(view, "󰓾") {
		t.Errorf("custom force glyph missing in:\n%s", view)
	}
	if strings.Contains(view, "?") {
		t.Errorf("blanked invalid glyph still drawn in:\n%s", view)
	}
}

// The screen fills the terminal: the panel and the key hints sit at the bottom
// rather than floating directly under a short list.
func TestScreenFillsTheTerminalWithTheFooterAtTheBottom(t *testing.T) {
	rendered := lines(sized(New(statusData()), 100, 30).View())
	if got := len(rendered); got != 30 {
		t.Errorf("view is %d lines tall, want 30", got)
	}
	if last := rendered[len(rendered)-1]; !strings.Contains(last, "q quit") {
		t.Errorf("last line = %q, want the key hints", last)
	}
}

// A filter applies to whichever tab is showing, so switching tabs can land on a
// cursor saved when that tab had more rows.
func TestSwitchingTabsUnderAFilterKeepsTheCursorInRange(t *testing.T) {
	m := sized(New(diffData()), 100, 30)
	m = press(t, m, "tab", "G")  // Mappings, last row
	m = press(t, m, "shift+tab") // back to Changes
	m = press(t, m, "/", "lazy") // matches one change, no mapping
	m = press(t, m, "enter")     // leave the filter input, keeping the query
	m = press(t, m, "tab")       // Mappings, now empty under the filter
	if got := m.cursor[m.tab()]; got != 0 {
		t.Errorf("cursor = %d, want 0 for an empty filtered tab", got)
	}
	if got := plain(m.View()); !strings.Contains(got, "No rows match the filter") {
		t.Errorf("expected the empty-filter message in:\n%s", got)
	}
}
