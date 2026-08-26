package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// tab identifies one of the cockpit's screens.
type tab int

const (
	tabChanges tab = iota
	tabMappings
	tabConfig
)

func (t tab) title() string {
	switch t {
	case tabChanges:
		return "Changes"
	case tabMappings:
		return "Mappings"
	default:
		return "Config"
	}
}

// defaultWidth/defaultHeight are used until the first WindowSizeMsg arrives,
// and are the smallest terminal the layout is designed for.
const (
	defaultWidth  = 80
	defaultHeight = 24
)

// flagSlot is one column of the mappings table's flag gutter. Each flag keeps
// its own column so the gutter reads vertically: every `force` glyph lands in
// the same place, whether or not the row has the other flags.
type flagSlot struct {
	glyph string
	width int
	style lipgloss.Style
	name  string
	help  string
	on    func(MappingRow) bool
}

// configLine is one line of the Config tab; section lines are headings.
type configLine struct {
	key     string
	value   string
	section bool
}

// Model is the cockpit's Bubble Tea model. It owns only presentation state —
// the Data it draws is a snapshot taken before the program started.
type Model struct {
	data  Data
	th    theme
	slots []flagSlot

	tabs   []tab
	active int
	cursor map[tab]int

	filter     textinput.Model
	filtering  bool
	showLegend bool
	showDetail bool

	width, height int
	quitting      bool
}

// New builds the cockpit for a snapshot. `status` (which does not diff) gets
// Mappings and Config; the preview commands additionally get Changes, and open
// on it.
func New(d Data) Model {
	tabs := []tab{tabMappings, tabConfig}
	if d.ShowChanges {
		tabs = append([]tab{tabChanges}, tabs...)
	}
	th := newTheme(d.Colors)
	fi := textinput.New()
	fi.Prompt = "filter: "
	fi.Placeholder = "type to narrow, esc to clear"
	fi.CharLimit = 120
	fi.PromptStyle = th.footerKey
	fi.PlaceholderStyle = th.subtle

	return Model{
		data:       d,
		th:         th,
		slots:      flagSlots(d, th),
		tabs:       tabs,
		cursor:     map[tab]int{},
		filter:     fi,
		showDetail: true,
		width:      defaultWidth,
		height:     defaultHeight,
	}
}

func flagSlots(d Data, th theme) []flagSlot {
	all := []flagSlot{
		{glyph: d.Icons.Force, style: th.force, name: "force", help: "the source overwrites the destination",
			on: func(r MappingRow) bool { return r.Force }},
		{glyph: d.Icons.Only, style: th.only, name: "only", help: "filtered by an 'only' whitelist",
			on: func(r MappingRow) bool { return r.Only }},
		{glyph: d.Icons.Ignore, style: th.ignore, name: "ignore", help: "filtered by an 'ignore' blacklist",
			on: func(r MappingRow) bool { return r.Ignore }},
		{glyph: d.Icons.Hook, style: th.hook, name: "hooks", help: "post-sync hooks configured",
			on: func(r MappingRow) bool { return r.Hooks }},
		{glyph: d.Icons.Invalid, style: th.invalid, name: "invalid", help: "invalid source or destination path",
			on: func(r MappingRow) bool { return !r.Valid }},
	}
	out := make([]flagSlot, 0, len(all))
	for _, s := range all {
		s.glyph = strings.TrimSpace(s.glyph)
		if s.glyph == "" { // the icon set can blank a glyph out; drop its column
			continue
		}
		s.width = lipgloss.Width(s.glyph)
		out = append(out, s)
	}
	return out
}

// Init satisfies tea.Model; the snapshot is complete, so there is nothing to do.
func (m Model) Init() tea.Cmd { return nil }

// Update handles window resizes and key input.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		return m, nil
	case tea.KeyMsg:
		if m.filtering {
			return m.updateFilter(msg)
		}
		return m.updateKey(msg)
	}
	return m, nil
}

func (m Model) updateFilter(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		m.quitting = true
		return m, tea.Quit
	case "esc":
		m.filtering = false
		m.filter.SetValue("")
		m.filter.Blur()
		return m.clamped(), nil
	case "enter":
		m.filtering = false
		m.filter.Blur()
		return m.clamped(), nil
	}
	var cmd tea.Cmd
	m.filter, cmd = m.filter.Update(msg)
	return m.clamped(), cmd
}

func (m Model) updateKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	t := m.tab()
	last := max(len(m.visible())-1, 0)
	switch msg.String() {
	case "q", "esc", "ctrl+c":
		m.quitting = true
		return m, tea.Quit
	case "j", "down":
		m.cursor[t] = min(m.cursor[t]+1, last)
	case "k", "up":
		m.cursor[t] = max(m.cursor[t]-1, 0)
	case "pgdown", "ctrl+d", "ctrl+f":
		m.cursor[t] = min(m.cursor[t]+m.page(), last)
	case "pgup", "ctrl+u", "ctrl+b":
		m.cursor[t] = max(m.cursor[t]-m.page(), 0)
	case "g", "home":
		m.cursor[t] = 0
	case "G", "end":
		m.cursor[t] = last
	case "tab", "right":
		m.active = (m.active + 1) % len(m.tabs)
	case "shift+tab", "left":
		m.active = (m.active - 1 + len(m.tabs)) % len(m.tabs)
	case "l", "?":
		m.showLegend = !m.showLegend
	case "d", "enter":
		m.showDetail = !m.showDetail
	case "/":
		m.filtering = true
		m.showLegend = false
		return m, m.filter.Focus()
	}
	// A tab switch lands on a cursor saved before the filter narrowed that tab.
	return m.clamped(), nil
}

// clamped keeps the cursor inside the filtered row set.
func (m Model) clamped() Model {
	t := m.tab()
	if n := len(m.visible()); m.cursor[t] >= n {
		m.cursor[t] = max(n-1, 0)
	}
	return m
}

// page is the number of rows a page key moves, derived from the window height
// minus the fixed chrome.
func (m Model) page() int { return max(m.height-9, 1) }

func (m Model) tab() tab { return m.tabs[m.active] }

// Quitting reports whether the user asked to leave; the caller prints the
// summary only for a real exit.
func (m Model) Quitting() bool { return m.quitting }

// --- filtering -------------------------------------------------------------

// visible returns the indices of the active tab's rows that match the filter,
// in display order.
func (m Model) visible() []int {
	q := strings.ToLower(strings.TrimSpace(m.filter.Value()))
	var out []int
	switch m.tab() {
	case tabChanges:
		for i, c := range m.data.Changes {
			if q == "" || strings.Contains(strings.ToLower(c.Path), q) {
				out = append(out, i)
			}
		}
	case tabMappings:
		for i, r := range m.data.Mappings {
			if q == "" || strings.Contains(strings.ToLower(r.Src+" "+r.Dest+" "+r.RealSrc+" "+r.RealDest), q) {
				out = append(out, i)
			}
		}
	default:
		for i, l := range m.configLines() {
			if q == "" || l.section || strings.Contains(strings.ToLower(l.key+" "+l.value), q) {
				out = append(out, i)
			}
		}
	}
	return out
}

func (m Model) total() int {
	switch m.tab() {
	case tabChanges:
		return len(m.data.Changes)
	case tabMappings:
		return len(m.data.Mappings)
	default:
		return len(m.configLines())
	}
}

func (m Model) configLines() []configLine {
	var out []configLine
	section := func(name string) { out = append(out, configLine{key: name, section: true}) }
	if len(m.data.Options) > 0 {
		section("Options")
		for _, kv := range m.data.Options {
			out = append(out, configLine{key: kv.Key, value: kv.Value})
		}
	}
	if len(m.data.EnvVars) > 0 {
		section("Environment")
		for _, kv := range m.data.EnvVars {
			out = append(out, configLine{key: kv.Key, value: kv.Value})
		}
	}
	if len(m.data.HookCmds) > 0 {
		section("Hooks to run")
		for _, c := range m.data.HookCmds {
			out = append(out, configLine{value: c})
		}
	}
	if len(m.data.Notices) > 0 {
		section("Notices")
		for _, n := range m.data.Notices {
			out = append(out, configLine{value: n})
		}
	}
	return out
}

// --- view ------------------------------------------------------------------

// minRows is the number of rows the list keeps for itself. On a short terminal
// the detail pane gives way rather than squeezing the list out of the screen;
// the legend, which the user asked for explicitly, does not.
const minRows = 4

// View renders the whole screen: header, tab bar, the active tab's rows, an
// optional detail or legend panel, and the footer.
func (m Model) View() string {
	if m.quitting {
		return ""
	}
	w := max(m.width, 20)
	header := m.headerView(w)
	tabs := m.tabsView(w)
	footer := m.footerView(w)
	panel := m.panelView(w)

	chrome := lipgloss.Height(header) + lipgloss.Height(tabs) + lipgloss.Height(footer)
	if m.tab() == tabMappings {
		chrome++ // column header
	}
	avail := max(m.height-chrome, 1)
	if panel != "" && avail-lipgloss.Height(panel) < minRows && !m.showLegend {
		panel = ""
	}
	rowsH := avail
	if panel != "" {
		rowsH = max(avail-lipgloss.Height(panel), 1)
	}

	parts := []string{header, tabs}
	if m.tab() == tabMappings {
		parts = append(parts, m.columnHeader(w))
	}
	parts = append(parts, padLines(m.rowsView(w, rowsH), rowsH))
	if panel != "" {
		parts = append(parts, panel)
	}
	parts = append(parts, footer)
	return strings.Join(parts, "\n")
}

func (m Model) headerView(w int) string {
	left := m.th.title.Render("dotsync "+m.data.Command) + " " + m.th.subtle.Render(m.data.ConfigPath)
	right := m.th.accent.Render(strings.ToUpper(m.data.Direction))
	line1 := spread(left, right, w)

	counts := []string{
		fmt.Sprintf("%d mapping%s", len(m.data.Mappings), plural(len(m.data.Mappings))),
		m.th.subtle.Render(fmt.Sprintf("%d valid", m.data.ValidCount())),
	}
	if n := m.data.InvalidCount(); n > 0 {
		counts = append(counts, m.th.invalid.Render(fmt.Sprintf("%d invalid", n)))
	}
	if m.data.ShowChanges {
		counts = append(counts,
			m.th.added.Render(fmt.Sprintf("%d added", m.data.CountByKind(KindAdded))),
			m.th.modified.Render(fmt.Sprintf("%d modified", m.data.CountByKind(KindModified))),
			m.th.removed.Render(fmt.Sprintf("%d removed", m.data.CountByKind(KindRemoved))),
		)
	}
	line2 := strings.Join(counts, m.th.subtle.Render(" · "))
	return line1 + "\n" + line2 + "\n" + m.th.rule.Render(strings.Repeat("─", w))
}

func (m Model) tabsView(w int) string {
	cells := make([]string, 0, len(m.tabs))
	for i, t := range m.tabs {
		label := " " + t.title() + " "
		if i == m.active {
			cells = append(cells, m.th.tabActive.Render(label))
		} else {
			cells = append(cells, m.th.tabInactive.Render(label))
		}
	}
	return strings.Join(cells, m.th.subtle.Render("│"))
}

func (m Model) columnHeader(w int) string {
	l := m.layout(w)
	head := strings.Repeat(" ", l.gutter) + fit("FLAGS", l.flags)
	if l.flags > 0 {
		head += " "
	}
	head += fit("SOURCE", l.src) + "   " + fit("DESTINATION", l.dest)
	if l.counts > 0 {
		head += " " + fit("CHANGES", l.counts)
	}
	return m.th.colHeader.Render(head)
}

// layout is the mappings table's column geometry for a given width.
type layout struct {
	gutter int // cursor marker
	flags  int
	src    int
	dest   int
	counts int
}

func (m Model) layout(w int) layout {
	l := layout{gutter: 2}
	for i, s := range m.slots {
		if i > 0 {
			l.flags++
		}
		l.flags += s.width
	}
	if m.data.ShowChanges {
		l.counts = 12
	}
	rest := w - l.gutter - l.flags - l.counts - 4 // 3 for the arrow, 1 for a gap
	if l.flags > 0 {
		rest--
	}
	rest = max(rest, 10)
	l.src = rest / 2
	l.dest = rest - l.src
	return l
}

func (m Model) rowsView(w, h int) string {
	idxs := m.visible()
	if len(idxs) == 0 {
		return m.th.subtle.Render("  " + m.emptyMessage())
	}
	cur := min(m.cursor[m.tab()], len(idxs)-1)

	// When the rows do not fit, the last line becomes a position indicator, so
	// that scrolling never hides where the cursor is in the list.
	rowsH, overflow := h, len(idxs) > h
	if overflow && h > 1 {
		rowsH = h - 1
	}
	off := 0
	if cur >= rowsH {
		off = cur - rowsH + 1
	}
	end := min(off+rowsH, len(idxs))

	lines := make([]string, 0, h)
	for i := off; i < end; i++ {
		lines = append(lines, m.rowView(idxs[i], i == cur, w))
	}
	if overflow && h > 1 {
		lines = append(lines, m.th.subtle.Render(fmt.Sprintf("  row %d of %d", cur+1, len(idxs))))
	}
	return strings.Join(lines, "\n")
}

// padLines pads a block out to n lines so the panel and footer stay pinned to
// the bottom of the screen instead of floating under a short list.
func padLines(block string, n int) string {
	if missing := n - lipgloss.Height(block); missing > 0 {
		return block + strings.Repeat("\n", missing)
	}
	return block
}

func (m Model) emptyMessage() string {
	if strings.TrimSpace(m.filter.Value()) != "" {
		return "No rows match the filter."
	}
	switch m.tab() {
	case tabChanges:
		return "Everything is in sync."
	case tabMappings:
		return "No mappings configured for this direction."
	default:
		return "Nothing to show."
	}
}

func (m Model) rowView(idx int, selected bool, w int) string {
	switch m.tab() {
	case tabChanges:
		return m.changeRowView(m.data.Changes[idx], selected, w)
	case tabMappings:
		return m.mappingRowView(m.data.Mappings[idx], selected, w)
	default:
		return m.configRowView(m.configLines()[idx], selected, w)
	}
}

func (m Model) marker(selected bool) string {
	if selected {
		return m.th.cursor.Render("▸ ")
	}
	return "  "
}

func (m Model) mappingRowView(r MappingRow, selected bool, w int) string {
	l := m.layout(w)
	pathStyle := m.th.path
	if !r.Valid {
		pathStyle = m.th.invalid
	}
	if selected {
		pathStyle = pathStyle.Bold(true)
	}

	var b strings.Builder
	b.WriteString(m.marker(selected))
	if l.flags > 0 {
		b.WriteString(padTo(m.flagsCell(r), l.flags))
		b.WriteString(" ")
	}
	b.WriteString(padTo(m.th.stylePath(truncateMiddle(r.Src, l.src), pathStyle), l.src))
	b.WriteString(m.th.subtle.Render(" → "))
	b.WriteString(padTo(m.th.stylePath(truncateMiddle(r.Dest, l.dest), pathStyle), l.dest))
	if l.counts > 0 {
		b.WriteString(" " + padTo(m.countsCell(r), l.counts))
	}
	return b.String()
}

func (m Model) flagsCell(r MappingRow) string {
	cells := make([]string, 0, len(m.slots))
	for _, s := range m.slots {
		if s.on(r) {
			cells = append(cells, s.style.Render(s.glyph))
		} else {
			cells = append(cells, strings.Repeat(" ", s.width))
		}
	}
	return strings.Join(cells, " ")
}

func (m Model) countsCell(r MappingRow) string {
	if r.Changes() == 0 {
		return m.th.subtle.Render("—")
	}
	var parts []string
	if r.Added > 0 {
		parts = append(parts, m.th.added.Render(fmt.Sprintf("+%d", r.Added)))
	}
	if r.Modified > 0 {
		parts = append(parts, m.th.modified.Render(fmt.Sprintf("~%d", r.Modified)))
	}
	if r.Removed > 0 {
		parts = append(parts, m.th.removed.Render(fmt.Sprintf("-%d", r.Removed)))
	}
	return strings.Join(parts, " ")
}

func (m Model) changeRowView(c ChangeRow, selected bool, w int) string {
	style := m.th.styleForKind(c.Kind)
	icon := m.changeIcon(c.Kind)
	tag := ""
	if c.Orphan {
		tag = m.th.subtle.Render("  (orphan)")
	}
	avail := w - 2 - lipgloss.Width(icon) - lipgloss.Width(tag) - 1
	path := truncateMiddle(c.Path, max(avail, 10))
	if selected {
		style = style.Bold(true)
	}
	return m.marker(selected) + style.Render(icon) + m.th.stylePath(path, style) + tag
}

func (m Model) changeIcon(k Kind) string {
	switch k {
	case KindAdded:
		return m.data.Icons.DiffCreated
	case KindModified:
		return m.data.Icons.DiffUpdated
	default:
		return m.data.Icons.DiffRemoved
	}
}

func (m Model) configRowView(l configLine, selected bool, w int) string {
	if l.section {
		return "  " + m.th.colHeader.Render(strings.ToUpper(l.key))
	}
	// 24 columns fit the longest mirror variable name ($XDG_CONFIG_HOME_MIRROR)
	// without truncation, which is the common case on this tab.
	key := m.th.detailKey.Render(fit(l.key, 24))
	value := m.th.stylePath(truncateMiddle(l.value, max(w-28, 10)), m.th.path)
	return m.marker(selected) + key + " " + value
}

// --- panels ----------------------------------------------------------------

func (m Model) panelView(w int) string {
	if m.showLegend {
		return m.th.panel.Width(w - 2).Render(m.legendBody())
	}
	if !m.showDetail {
		return ""
	}
	body := m.detailBody(w)
	if body == "" {
		return ""
	}
	return m.th.panel.Width(w - 2).Render(body)
}

func (m Model) legendBody() string {
	lines := []string{m.th.colHeader.Render("LEGEND")}
	for _, s := range m.slots {
		lines = append(lines, s.style.Render(fit(s.glyph, 3))+m.th.detailKey.Render(fit(s.name, 9))+s.help)
	}
	kinds := []struct {
		icon  string
		style lipgloss.Style
		text  string
	}{
		{m.data.Icons.DiffCreated, m.th.added, "created in the destination"},
		{m.data.Icons.DiffUpdated, m.th.modified, "content differs, will be overwritten"},
		{m.data.Icons.DiffRemoved, m.th.removed, "removed from the destination"},
	}
	for _, k := range kinds {
		lines = append(lines, k.style.Render(fit(strings.TrimSpace(k.icon), 3))+m.th.detailKey.Render(fit("", 9))+k.text)
	}
	return strings.Join(lines, "\n")
}

// detailBody renders the selected row's detail pane.
func (m Model) detailBody(w int) string {
	idxs := m.visible()
	if len(idxs) == 0 {
		return ""
	}
	idx := idxs[min(m.cursor[m.tab()], len(idxs)-1)]
	switch m.tab() {
	case tabChanges:
		return m.changeDetail(m.data.Changes[idx], w)
	case tabMappings:
		return m.mappingDetail(m.data.Mappings[idx], w)
	default:
		return ""
	}
}

func (m Model) mappingDetail(r MappingRow, w int) string {
	var kv []KeyValue
	kv = append(kv, KeyValue{"src", r.RealSrc}, KeyValue{"dest", r.RealDest})
	if !r.Valid {
		kv = append(kv, KeyValue{"invalid", r.InvalidReason + " · fix: " + r.InvalidFix})
	}
	if r.Force {
		kv = append(kv, KeyValue{"force", "the destination is overwritten from the source"})
	}
	if len(r.OnlyPatterns) > 0 {
		kv = append(kv, KeyValue{"only", strings.Join(r.OnlyPatterns, ", ")})
	}
	if len(r.IgnorePatterns) > 0 {
		kv = append(kv, KeyValue{"ignore", strings.Join(r.IgnorePatterns, ", ")})
	}
	for i, h := range r.HookCommands {
		key := "hooks"
		if i > 0 {
			key = ""
		}
		kv = append(kv, KeyValue{key, h})
	}
	if r.Changes() > 0 {
		kv = append(kv, KeyValue{"changes", fmt.Sprintf("%d added, %d modified, %d removed", r.Added, r.Modified, r.Removed)})
	}
	return m.renderKV(kv, w)
}

func (m Model) changeDetail(c ChangeRow, w int) string {
	kind := map[Kind]string{KindAdded: "added", KindModified: "modified", KindRemoved: "removed"}[c.Kind]
	if c.Orphan {
		kind += " (orphan: tracked by a previous pull, no longer matched)"
	}
	return m.renderKV([]KeyValue{
		{"path", c.Path},
		{"change", kind},
		{"mapping", c.Mapping},
	}, w)
}

func (m Model) renderKV(kv []KeyValue, w int) string {
	lines := make([]string, 0, len(kv))
	for _, e := range kv {
		key := m.th.detailKey.Render(fit(e.Key, 8))
		lines = append(lines, key+" "+m.th.stylePath(truncateMiddle(e.Value, max(w-14, 10)), m.th.path))
	}
	return strings.Join(lines, "\n")
}

func (m Model) footerView(w int) string {
	if m.filtering {
		return m.filter.View()
	}
	if q := strings.TrimSpace(m.filter.Value()); q != "" {
		return m.th.footerKey.Render("filter: ") +
			m.th.path.Render(q) +
			m.th.subtle.Render(fmt.Sprintf("  %d/%d  (esc to clear)", len(m.visible()), m.total()))
	}
	hint := ""
	if m.data.ShowChanges && len(m.data.Changes) > 0 {
		hint = "preview only — run with --apply to sync"
	}
	return m.helpView(w, hint)
}

// helpView fits the key hints to the terminal: the full list when it fits
// beside the hint, a shorter one when it does not, and the hint on its own line
// when even that is too wide. The hint is the one part that never drops — it is
// the answer to "how do I make this happen?".
func (m Model) helpView(w int, hint string) string {
	long := strings.Join([]string{"j/k move", "/ filter", "l legend", "d detail", "tab switch", "q quit"}, " · ")
	short := strings.Join([]string{"j/k", "/ filter", "l legend", "q quit"}, " · ")
	styledHint := m.th.subtle.Render(hint)

	for _, keys := range []string{long, short} {
		help := m.th.footer.Render(keys)
		if hint == "" {
			if lipgloss.Width(keys) <= w {
				return help
			}
			continue
		}
		if lipgloss.Width(keys)+lipgloss.Width(hint)+2 <= w {
			return spread(help, styledHint, w)
		}
	}
	if hint == "" {
		return m.th.footer.Render(fit(short, w))
	}
	if lipgloss.Width(short) <= w {
		return m.th.footer.Render(short) + "\n" + m.th.subtle.Render(fit(hint, w))
	}
	return m.th.subtle.Render(fit(hint, w))
}

// Compile-time assurance that the cockpit satisfies tea.Model.
var _ tea.Model = Model{}
