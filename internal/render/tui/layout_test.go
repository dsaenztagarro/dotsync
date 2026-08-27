package tui

import (
	"strings"
	"testing"
	"unicode/utf8"
)

// The cockpit has to be legible at any terminal size, so the layout rules are
// tested as rules: the same content is measured across viewports, from a 32"
// screen down to a phone-sized pane.

func TestLayoutReflowsToTheViewport(t *testing.T) {
	cases := []struct {
		name      string
		w, h      int
		panel     panelPlacement
		rowHeight int
		colHeader bool
	}{
		{"32-inch screen: the panel moves beside the list", 236, 58, panelBeside, 1, true},
		{"wide window: still beside", 160, 40, panelBeside, 1, true},
		{"laptop: the panel stacks below", 120, 30, panelBeside, 1, true},
		{"half a laptop screen: columns share the width", 90, 24, panelBelow, 1, true},
		{"narrow: the differing destination stacks per row", 60, 20, panelBelow, 2, false},
		{"very narrow: still usable", 46, 16, panelBelow, 2, false},
		{"short: the panel yields the screen to the list", 110, 11, panelHidden, 1, true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p := sized(New(statusData()), c.w, c.h).resolve()
			if p.panel != c.panel {
				t.Errorf("panel placement = %v, want %v", p.panel, c.panel)
			}
			if p.rowHeight != c.rowHeight {
				t.Errorf("row height = %d, want %d", p.rowHeight, c.rowHeight)
			}
			if p.colHeader != c.colHeader {
				t.Errorf("column header = %v, want %v", p.colHeader, c.colHeader)
			}
			if p.content > c.w {
				t.Errorf("content width %d overflows the viewport %d", p.content, c.w)
			}
		})
	}
}

// The complaint that started this: on a wide screen the proportional split put
// the arrow a hundred columns from the source it belonged to. Columns now take
// their width from the paths they hold, at any viewport size.
func TestColumnsAreSizedToContentNotToTheViewport(t *testing.T) {
	d := statusData()
	longestPath, longestDest := 0, 0
	for _, r := range d.Mappings {
		s := scopeOf(r)
		longestPath = max(longestPath, len(s.srcCell()))
		longestDest = max(longestDest, len(s.dest))
	}

	for _, w := range []int{120, 160, 236, 400} {
		p := sized(New(d), w, 40).resolve()
		if !p.scoped {
			t.Fatalf("at %d columns: expected the scoped layout", w)
		}
		if p.table.primary != longestPath {
			t.Errorf("at %d columns: path column = %d, want the longest path (%d)", w, p.table.primary, longestPath)
		}
		if p.table.second != longestDest {
			t.Errorf("at %d columns: destination column = %d, want the longest differing destination (%d)", w, p.table.second, longestDest)
		}
	}

	// And the rendered arrow lands immediately after that column, not at the
	// middle of the screen.
	m := sized(New(d), 236, 40)
	p := m.resolve()
	want := p.table.gutter + p.table.lead + 1 + p.table.scope + 2 + p.table.primary
	for _, l := range lines(m.View()) {
		if i := strings.Index(l, " → "); i >= 0 {
			if col := utf8.RuneCountInString(l[:i]); col != want {
				t.Errorf("arrow at column %d, want %d (right after the path column)", col, want)
			}
		}
	}
}

// Filtering changes the content, so the columns re-measure with it.
func TestFilteringResizesTheColumns(t *testing.T) {
	m := sized(New(statusData()), 200, 30)
	before := m.resolve().table
	filtered := press(t, m, "/", "ssh") // leaves only the short $HOME/.ssh row
	after := filtered.resolve().table

	if after.primary >= before.primary {
		t.Errorf("source column did not shrink with the content: %d -> %d", before.primary, after.primary)
	}
	if after.lead >= before.lead {
		t.Errorf("flag gutter did not shrink: %d -> %d (the remaining row has only 'only' and 'hooks')", before.lead, after.lead)
	}
}

// A flag no visible row carries does not get a column.
func TestFlagGutterOnlyPaysForFlagsInUse(t *testing.T) {
	d := statusData()
	for i := range d.Mappings {
		d.Mappings[i].Hooks = false // nothing has hooks now
	}
	p := sized(New(d), 120, 30).resolve()
	for _, s := range p.slots {
		if s.name == "hooks" {
			t.Fatal("reserved a hook column no row uses")
		}
	}
	if got, want := p.table.lead, flagsWidth(p.slots); got != want {
		t.Errorf("lead column = %d, want %d", got, want)
	}
}

// On a wide screen the panel grows to fit its own content and stops there: the
// list is sized to its content too, so neither starves the other.
func TestSidePanelGrowsToItsContentAndStops(t *testing.T) {
	m := sized(New(statusData()), 236, 40)
	p := m.resolve()
	if p.panel != panelBeside {
		t.Fatalf("panel placement = %v, want beside", p.panel)
	}
	if p.panelWidth < minPanelWidth {
		t.Errorf("panel width %d is below the legibility floor %d", p.panelWidth, minPanelWidth)
	}
	if p.panelWidth > maxPanelWidth {
		t.Errorf("panel width %d exceeds the cap %d", p.panelWidth, maxPanelWidth)
	}
	if want := clamp(minPanelWidth, m.panelContentWidth()+4, maxPanelWidth); p.panelWidth != want {
		t.Errorf("panel width = %d, want its content width %d", p.panelWidth, want)
	}
	if p.table.total()+1+p.panelWidth > 236 {
		t.Errorf("list and panel together (%d) overflow the viewport", p.table.total()+1+p.panelWidth)
	}
}

// A side panel must fit whole: the plan reserves its width, so the frame has to
// render its right border rather than clipping it at the screen edge.
func TestSidePanelKeepsItsBorderOnScreen(t *testing.T) {
	for _, w := range []int{130, 150, 180, 236} {
		m := sized(New(statusData()), w, 30)
		if m.resolve().panel != panelBeside {
			continue
		}
		view := plain(m.View())
		if !strings.Contains(view, "╮") || !strings.Contains(view, "╯") {
			t.Errorf("at %d columns the panel border is clipped:\n%s", w, view)
		}
	}
}

// Beside means beside: the panel's first line shares a screen line with the
// first row, so the detail sits next to the selection.
func TestSidePanelIsTopAlignedWithTheList(t *testing.T) {
	view := plain(sized(New(statusData()), 236, 40).View())
	for _, l := range lines(view) {
		if strings.Contains(l, "nvim") && !strings.Contains(l, "src") {
			if !strings.Contains(l, "╭") {
				t.Errorf("first row does not share its line with the panel top:\n%q", l)
			}
			return
		}
	}
	t.Fatal("no mapping row found")
}

// A stacked panel hugs the last row instead of floating at the bottom of a tall
// screen; only the key hints stay pinned there.
func TestStackedPanelHugsTheList(t *testing.T) {
	d := statusData()
	rendered := lines(sized(New(d), 90, 40).View()) // narrow enough that the panel stacks

	lastRow, panelTop, footer := -1, -1, -1
	for i, l := range rendered {
		if strings.Contains(l, "cabal/config") && !strings.Contains(l, "invalid") && !strings.Contains(l, "dest") {
			lastRow = i
		}
		if strings.HasPrefix(strings.TrimSpace(l), "╭") && panelTop < 0 {
			panelTop = i
		}
		if strings.Contains(l, "q quit") {
			footer = i
		}
	}
	if lastRow < 0 || panelTop < 0 || footer < 0 {
		t.Fatalf("missing landmarks: row=%d panel=%d footer=%d", lastRow, panelTop, footer)
	}
	if panelTop != lastRow+1 {
		t.Errorf("panel starts at line %d, want %d (directly under the last row)", panelTop, lastRow+1)
	}
	if footer != len(rendered)-1 {
		t.Errorf("footer at line %d, want the last line (%d)", footer, len(rendered)-1)
	}
}

// Nothing is pinned to a far edge any more: the direction badge travels with
// the title instead of sitting 200 columns away from it.
func TestHeaderStaysInlineOnAWideScreen(t *testing.T) {
	head := lines(sized(New(statusData()), 236, 40).View())[0]
	if !strings.Contains(head, "dotsync status · PUSH") {
		t.Errorf("header is not inline: %q", head)
	}
	if utf8.RuneCountInString(head) > 120 {
		t.Errorf("header line stretched to %d columns: %q", utf8.RuneCountInString(head), head)
	}
}

// The header sheds its least important part before it overflows.
func TestHeaderDropsTheConfigPathWhenItCannotFit(t *testing.T) {
	head := lines(sized(New(statusData()), 36, 16).View())[0]
	if strings.Contains(head, "dotsync.toml") {
		t.Errorf("config path survived on a narrow screen: %q", head)
	}
	if !strings.Contains(head, "dotsync status") {
		t.Errorf("command name did not survive: %q", head)
	}
}

// The property that matters at every size: the frame fits the terminal.
func TestFrameFitsEveryViewport(t *testing.T) {
	for _, d := range []Data{statusData(), diffData()} {
		for w := 24; w <= 260; w += 11 {
			for h := 6; h <= 60; h += 7 {
				m := sized(New(d), w, h)
				for _, keys := range [][]string{nil, {"G"}, {"l"}, {"/", "n"}} {
					view := press(t, m, keys...).View()
					for i, l := range lines(view) {
						if got := utf8.RuneCountInString(l); got > w {
							t.Fatalf("%dx%d keys=%v: line %d is %d columns wide:\n%q", w, h, keys, i, got, l)
						}
					}
					if got := len(lines(view)); got > h {
						t.Fatalf("%dx%d keys=%v: frame is %d lines tall", w, h, keys, got)
					}
				}
			}
		}
	}
}
