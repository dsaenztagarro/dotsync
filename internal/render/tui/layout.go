package tui

import "github.com/charmbracelet/lipgloss"

// The cockpit reflows on every frame instead of assuming a terminal size. This
// file holds the whole rule set: `plan` measures the content and the viewport
// and returns the arrangement to draw, so the view functions never make layout
// decisions of their own and the rules can be tested without a terminal.
//
// The governing idea is borrowed from the web: columns are sized to their
// CONTENT, not to the viewport. Width that the content does not need is left
// empty at the edge rather than distributed into the gaps — a 236-column screen
// must not push a mapping's `→` a hundred columns away from its source path.

// Layout thresholds, in terminal cells. They are named for what they enable,
// not for a device class, and every one of them is a floor on legibility rather
// than a chosen aesthetic.
const (
	minWidth      = 24  // below this nothing can be laid out; content is clipped
	gutterWidth   = 2   // the cursor marker column
	arrowWidth    = 3   // " → "
	countsWidth   = 12  // "+12 ~34 -56"
	minColumn     = 12  // a path column never shrinks past this
	minPairWidth  = 64  // src and dest stop sharing a line below this
	minPanelWidth = 44  // a panel narrower than this is not worth drawing
	maxPanelWidth = 100 // past this a panel is a wall of text, not a detail view
	minContent    = 40  // the header rule never shrinks past this
)

// Vertical thresholds, in terminal rows.
const (
	minPanelHeight = 12 // below this the list and the key hints own the screen
	minRows        = 4  // the list keeps at least this many rows
	minRuleHeight  = 10 // below this the header's rule costs a row it cannot spare
	headerHeight   = 2  // title and counts
	tabsHeight     = 1
)

// panelPlacement is where the detail or legend panel goes this frame.
type panelPlacement int

const (
	panelHidden panelPlacement = iota
	panelBelow
	panelBeside
)

// tableWidths is the row geometry for the active tab: the cursor gutter, a lead
// column (flag glyphs on Mappings, the change icon on Changes, the key on
// Config), the primary column (source path, change path, config value), and on
// Mappings the destination column plus the per-mapping change counts.
type tableWidths struct {
	gutter  int
	lead    int
	scope   int // the root each side lives under, on Mappings when it is lifted out
	primary int
	second  int // 0 when there is no destination column to draw
	counts  int
	folded  bool // the destination moved onto its own line
}

// total is the width one row occupies, gaps included.
func (t tableWidths) total() int {
	w := t.gutter + t.primary
	if t.lead > 0 {
		w += t.lead + 1
	}
	if t.scope > 0 {
		w += t.scope + 2
	}
	if t.second > 0 {
		w += arrowWidth + t.second
	}
	if t.counts > 0 {
		w += 1 + t.counts
	}
	return w
}

// plan is the resolved layout for one frame.
type plan struct {
	width   int // the viewport
	height  int
	content int // columns the cockpit actually occupies

	slots     []flagSlot // the flag columns this frame reserves
	table     tableWidths
	scoped    bool // rows show a scope and the path beneath it, not two full paths
	rowHeight int  // 1, or 2 when a row's paths stack
	colHeader bool // the FLAGS/SOURCE/DESTINATION row
	rule      bool // the line under the header
	rows      int  // lines the list may use

	panel       panelPlacement
	panelWidth  int
	panelHeight int
}

// items is how many rows fit in the list area.
func (p plan) items() int { return max(p.rows/p.rowHeight, 1) }

// resolve measures this frame — the viewport, the active tab's content, and the
// panel the user has open — and returns the arrangement to draw.
func (m Model) resolve() plan {
	w := max(m.width, minWidth)
	p := plan{width: w, height: max(m.height, 4)}

	p.slots = m.activeSlots()
	p.scoped = m.tab() == tabMappings && m.scopedRows() >= 2
	p.table = m.columns(w, p.slots, p.scoped)
	p.rowHeight = 1
	if p.table.folded {
		p.rowHeight = 2
	}
	p.colHeader = m.tab() == tabMappings && !p.table.folded && p.height >= minRuleHeight
	p.rule = p.height >= minRuleHeight

	p.content = min(w, max(p.table.total(), m.headerWidth(), minContent))
	m.placePanel(&p)
	m.splitHeight(&p)
	return p
}

// columns sizes the active tab's columns to the content they hold. Columns that
// fit keep their natural width; only when the row cannot fit is width taken
// away, and then from the column that is over its share.
func (m Model) columns(w int, slots []flagSlot, scoped bool) tableWidths {
	t := tableWidths{gutter: gutterWidth}
	primaryNeed, secondNeed := m.contentNeeds()

	switch m.tab() {
	case tabMappings:
		t.lead = flagsWidth(slots)
		if t.lead+1 > w/4 {
			t.lead = 0 // on a tiny screen the paths outrank the flag gutter
		}
		if m.data.ShowChanges && w >= minPairWidth {
			t.counts = countsWidth
		}
		if scoped {
			t.scope, primaryNeed, secondNeed = m.scopedNeeds()
			if t.scope+2 > w/3 {
				t.scope = max(w/3-2, 0) // the scope is a label, never the row
			}
		}
		avail := m.available(t, w)
		if scoped && secondNeed == 0 {
			// No row's destination differs from its source: there is nothing
			// for a destination column to say.
			t.primary = min(primaryNeed, avail)
			return t
		}
		if avail-arrowWidth >= minPairWidth {
			t.primary, t.second = fitColumns(avail-arrowWidth, primaryNeed, secondNeed)
			return t
		}
		// Too narrow to keep a pair on one line: the destination stacks under
		// the source, so each column may use the full row.
		t.folded = true
		t.primary = min(primaryNeed, avail)
		return t
	case tabChanges:
		t.lead = lipgloss.Width(m.changeIcon(KindAdded))
		t.primary = min(primaryNeed, m.available(t, w))
		return t
	default: // Config: a key column sized to the longest key, then its value
		t.lead = min(primaryNeed, max(w/3, minColumn))
		t.primary = min(secondNeed, max(w-t.gutter-t.lead-1, minColumn))
		return t
	}
}

// available is the width left for the path columns once the fixed ones are out.
func (m Model) available(t tableWidths, w int) int {
	fixed := t.gutter
	if t.lead > 0 {
		fixed += t.lead + 1
	}
	if t.scope > 0 {
		fixed += t.scope + 2
	}
	if t.counts > 0 {
		fixed += 1 + t.counts
	}
	return max(w-fixed, minColumn)
}

// fitColumns splits avail between two content-sized columns. When both fit they
// keep their natural width and the remainder is left unused — padding it into
// the gap is exactly what makes a wide screen unreadable. Otherwise the column
// that fits within its share keeps its size and the other takes what is left.
func fitColumns(avail, aNeed, bNeed int) (int, int) {
	if aNeed+bNeed <= avail {
		return aNeed, bNeed
	}
	half := avail / 2
	switch {
	case aNeed <= half:
		return aNeed, avail - aNeed
	case bNeed <= half:
		return avail - bNeed, bNeed
	default:
		return half, avail - half
	}
}

// placePanel decides whether the detail/legend panel sits beside the list, below
// it, or not at all. Beside is preferred whenever the row geometry leaves real
// room, which is what turns spare width on a wide screen into information.
func (m Model) placePanel(p *plan) {
	if !m.panelWanted() || p.height < minPanelHeight {
		p.panel = panelHidden
		return
	}
	if spare := p.width - p.table.total() - 1; spare >= minPanelWidth {
		// The panel grows to fit its own content and stops there: the list is
		// already sized to its own, so the two never compete for the same cell.
		p.panel = panelBeside
		p.panelWidth = min(spare, clamp(minPanelWidth, m.panelContentWidth()+4, maxPanelWidth))
		p.content = min(p.width, p.table.total()+1+p.panelWidth)
		return
	}
	p.panel = panelBelow
	p.panelWidth = min(p.width, max(p.table.total(), minPanelWidth))
}

// scopedRows counts the mappings whose paths are rooted in a variable. The
// scope column is only worth its width when it factors out more than one row;
// a config of absolute paths keeps the full-path rendering.
func (m Model) scopedRows() int {
	n := 0
	for _, i := range m.visible() {
		if scopeOf(m.data.Mappings[i]).ok {
			n++
		}
	}
	return n
}

// activeSlots is the flag gutter this frame pays for: only the flags at least
// one visible mapping actually carries. A config with no hooks does not reserve
// a hook column, and a filtered view narrows the gutter with the rows.
func (m Model) activeSlots() []flagSlot {
	if m.tab() != tabMappings {
		return nil
	}
	idxs := m.visible()
	out := make([]flagSlot, 0, len(m.slots))
	for _, s := range m.slots {
		for _, i := range idxs {
			if s.on(m.data.Mappings[i]) {
				out = append(out, s)
				break
			}
		}
	}
	return out
}

// clamp keeps v within [lo, hi].
func clamp(lo, v, hi int) int { return max(lo, min(v, hi)) }

// panelWanted reports whether there is a panel to place at all.
func (m Model) panelWanted() bool {
	if m.showLegend {
		return true
	}
	return m.showDetail && m.tab() != tabConfig && len(m.visible()) > 0
}

// panelContentWidth is the panel's natural width: its longest line plus the
// border and padding, capped where a longer line stops being easier to read.
func (m Model) panelContentWidth() int {
	body := m.panelBody()
	lw := labelWidth(body)
	longest := 0
	for _, line := range body {
		longest = max(longest, line.natural(lw))
	}
	return min(longest, maxPanelWidth)
}

// splitHeight divides the rows left after the fixed chrome between the list and
// a stacked panel. The list keeps minRows; a detail panel that would break that
// yields entirely, while a legend the user opened on purpose is clipped instead.
func (m Model) splitHeight(p *plan) {
	chrome := headerHeight + tabsHeight + m.footerHeight(p.content)
	if p.rule {
		chrome++
	}
	if p.colHeader {
		chrome++
	}
	body := max(p.height-chrome, 1)

	if p.panel != panelBelow {
		p.rows = body
		if p.panel == panelBeside {
			p.panelHeight = min(len(m.panelBody())+2, body)
		}
		return
	}

	wanted := len(m.panelBody()) + 2
	if body-wanted < minRows {
		if !m.showLegend {
			p.panel = panelHidden
			p.rows = body
			return
		}
		wanted = max(body-minRows, 3)
	}
	p.panelHeight = wanted
	p.rows = max(body-wanted, 1)
}
