package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
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

// page is how far a page key moves: one screenful of the list as the current
// layout resolved it.
func (m Model) page() int { return m.resolve().items() }

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

// --- measurement ------------------------------------------------------------

// flagsWidth is the width of a flag gutter: one column per glyph, single-space
// separated, so each flag keeps its own column.
func flagsWidth(slots []flagSlot) int {
	w := 0
	for i, s := range slots {
		if i > 0 {
			w++
		}
		w += s.width
	}
	return w
}

// contentNeeds is the natural width of the active tab's two columns: source and
// destination on Mappings, the path on Changes, key and value on Config. This
// is what makes the table size to its content instead of to the viewport.
func (m Model) contentNeeds() (primary, second int) {
	switch m.tab() {
	case tabChanges:
		for _, i := range m.visible() {
			c := m.data.Changes[i]
			w := lipgloss.Width(c.Path)
			if c.Orphan {
				w += lipgloss.Width(orphanTag)
			}
			primary = max(primary, w)
		}
	case tabMappings:
		primary, second = lipgloss.Width(colSource), lipgloss.Width(colDest)
		for _, i := range m.visible() {
			r := m.data.Mappings[i]
			primary = max(primary, lipgloss.Width(r.Src))
			second = max(second, lipgloss.Width(r.Dest))
		}
	default:
		for _, l := range m.configLines() {
			primary = max(primary, lipgloss.Width(l.key))
			second = max(second, lipgloss.Width(l.value))
		}
	}
	return primary, second
}

// scopedNeeds is the natural width of the scoped columns: the scope label, the
// path beneath the source root, and the destination path for the rows whose
// destination is not simply the source path again. A zero destination need
// means no row differs, so that column is not drawn at all.
func (m Model) scopedNeeds() (scope, src, dest int) {
	scope, src = lipgloss.Width(colScope), lipgloss.Width(colPath)
	for _, i := range m.visible() {
		s := scopeOf(m.data.Mappings[i])
		scope = max(scope, lipgloss.Width(s.label))
		src = max(src, lipgloss.Width(s.srcCell()))
		if s.dest != "" {
			dest = max(dest, lipgloss.Width(s.dest))
		}
	}
	if dest > 0 {
		dest = max(dest, lipgloss.Width(colDest))
	}
	return scope, src, dest
}

// headerWidth is the natural width of the two header lines, so the rule under
// them spans the header even when the table is narrower.
func (m Model) headerWidth() int {
	return max(lipgloss.Width(plainJoin(m.titleSegments(), sep)),
		lipgloss.Width(plainJoin(m.countSegments(), sep)))
}

// --- view -------------------------------------------------------------------

const (
	sep       = " · "
	orphanTag = "  (orphan)"
	colSource = "SOURCE"
	colDest   = "DESTINATION"
	colScope  = "SCOPE"
	colPath   = "PATH"
)

// segment is one styled piece of a composed line. Lines are built as segments
// so their width can be measured before they are styled.
type segment struct {
	text  string
	style lipgloss.Style
}

func plainJoin(segs []segment, sep string) string {
	parts := make([]string, len(segs))
	for i, s := range segs {
		parts[i] = s.text
	}
	return strings.Join(parts, sep)
}

func (m Model) renderSegments(segs []segment, width int) string {
	parts := make([]string, len(segs))
	for i, s := range segs {
		parts[i] = s.style.Render(s.text)
	}
	line := strings.Join(parts, m.th.subtle.Render(sep))
	if lipgloss.Width(line) > width {
		return m.th.subtle.Render(fit(plainJoin(segs, sep), width))
	}
	return line
}

// View renders the frame the layout plan describes: header, tab bar, the active
// tab's rows, the detail or legend panel beside or below them, and the footer.
func (m Model) View() string {
	if m.quitting {
		return ""
	}
	p := m.resolve()

	out := []string{m.headerView(p), m.tabsView(p)}
	if p.colHeader {
		out = append(out, m.columnHeader(p))
	}
	list := m.rowsView(p)

	switch p.panel {
	case panelBeside:
		// The panel sits next to the selection; the list is padded to the full
		// row area so the footer stays at the bottom edge.
		// The panel carries its own left margin, so joining adds no separator
		// of its own — a second one would push its right border off the screen.
		left := lipgloss.NewStyle().Width(p.table.total()).Render(padLines(list, p.rows))
		panel := clipLines(m.panelView(p), p.rows)
		out = append(out, lipgloss.JoinHorizontal(lipgloss.Top, left, panel))
	case panelBelow:
		// The panel hugs the last row rather than floating at the bottom of a
		// tall screen; the padding goes underneath it.
		out = append(out, padLines(list+"\n"+clipLines(m.panelView(p), p.panelHeight), p.rows+p.panelHeight))
	default:
		out = append(out, padLines(list, p.rows))
	}
	// Last-resort guard: whatever the arithmetic, the frame never exceeds the
	// terminal in either direction.
	return clipLines(clipWidth(strings.Join(append(out, m.footerView(p)), "\n"), p.width), p.height)
}

// titleSegments is the header's first line: what ran, in which direction, and
// against which config. They are kept inline — pinning the direction to the far
// right of a wide screen separates it from the thing it describes.
func (m Model) titleSegments() []segment {
	return []segment{
		{"dotsync " + m.data.Command, m.th.title},
		{strings.ToUpper(m.data.Direction), m.th.accent},
		{m.data.ConfigPath, m.th.subtle},
	}
}

func (m Model) countSegments() []segment {
	segs := []segment{
		{fmt.Sprintf("%d mapping%s", len(m.data.Mappings), plural(len(m.data.Mappings))), m.th.path},
		{fmt.Sprintf("%d valid", m.data.ValidCount()), m.th.subtle},
	}
	if n := m.data.InvalidCount(); n > 0 {
		segs = append(segs, segment{fmt.Sprintf("%d invalid", n), m.th.invalid})
	}
	if m.data.ShowChanges {
		segs = append(segs,
			segment{fmt.Sprintf("%d added", m.data.CountByKind(KindAdded)), m.th.added},
			segment{fmt.Sprintf("%d modified", m.data.CountByKind(KindModified)), m.th.modified},
			segment{fmt.Sprintf("%d removed", m.data.CountByKind(KindRemoved)), m.th.removed},
		)
	}
	return segs
}

func (m Model) headerView(p plan) string {
	title := m.titleSegments()
	// The config path is the first thing to go when the line will not fit.
	if lipgloss.Width(plainJoin(title, sep)) > p.content {
		title = title[:2]
	}
	head := m.renderSegments(title, p.content) + "\n" + m.renderSegments(m.countSegments(), p.content)
	if !p.rule {
		return head // a short screen spends its rows on content, not on decoration
	}
	return head + "\n" + m.th.rule.Render(strings.Repeat("─", p.content))
}

func (m Model) tabsView(plan) string {
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

func (m Model) columnHeader(p plan) string {
	t := p.table
	head := strings.Repeat(" ", t.gutter)
	if t.lead > 0 {
		head += fit("FLAGS", t.lead) + " "
	}
	source := colSource
	if t.scope > 0 {
		head += fit(colScope, t.scope) + "  "
		source = colPath
	}
	head += fit(source, t.primary)
	if t.second > 0 {
		head += strings.Repeat(" ", arrowWidth) + fit(colDest, t.second)
	}
	if t.counts > 0 {
		head += " " + fit("CHANGES", t.counts)
	}
	return m.th.colHeader.Render(head)
}

func (m Model) rowsView(p plan) string {
	idxs := m.visible()
	if len(idxs) == 0 {
		return m.th.subtle.Render("  " + m.emptyMessage())
	}
	cur := min(m.cursor[m.tab()], len(idxs)-1)
	height := func(i int) int { return m.rowLines(p, idxs[i]) }

	total := 0
	for i := range idxs {
		total += height(i)
	}
	budget := p.rows
	overflow := total > budget
	if overflow && budget > 1 {
		budget-- // the last line becomes the position indicator
	}

	// Rows are not all one line tall, so the window is grown by height: back
	// from the cursor as far as the budget allows, then forward into what is
	// left. The cursor is on screen by construction.
	off, end, used := cur, cur+1, height(cur)
	for off > 0 && used+height(off-1) <= budget {
		off--
		used += height(off)
	}
	for end < len(idxs) && used+height(end) <= budget {
		used += height(end)
		end++
	}

	lines := make([]string, 0, end-off+1)
	for i := off; i < end; i++ {
		lines = append(lines, m.rowView(p, idxs[i], i == cur))
	}
	if overflow {
		lines = append(lines, m.th.subtle.Render(fmt.Sprintf("  row %d of %d", cur+1, len(idxs))))
	}
	return clipLines(strings.Join(lines, "\n"), p.rows)
}

// rowLines is how many screen lines a row occupies: two only when the layout
// folded AND the row has a destination to fold onto the second line. Under the
// scoped layout most rows have none, so a narrow terminal still shows them all.
func (m Model) rowLines(p plan, idx int) int {
	if p.rowHeight == 1 || m.tab() != tabMappings {
		return 1
	}
	if p.scoped && scopeOf(m.data.Mappings[idx]).dest == "" {
		return 1
	}
	return 2
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

func (m Model) rowView(p plan, idx int, selected bool) string {
	switch m.tab() {
	case tabChanges:
		return m.changeRowView(p, m.data.Changes[idx], selected)
	case tabMappings:
		return m.mappingRowView(p, m.data.Mappings[idx], selected)
	default:
		return m.configRowView(p, m.configLines()[idx], selected)
	}
}

func (m Model) marker(selected bool) string {
	if selected {
		return m.th.cursor.Render("▸ ")
	}
	return "  "
}

func (m Model) mappingRowView(p plan, r MappingRow, selected bool) string {
	if p.scoped {
		return m.scopedRowView(p, r, selected)
	}
	t := p.table
	style := m.th.path
	if !r.Valid {
		style = m.th.invalid
	}
	if selected {
		style = style.Bold(true)
	}
	src := m.th.stylePath(truncateMiddle(r.Src, t.primary), style)

	lead := ""
	if t.lead > 0 {
		lead = padTo(m.flagsCell(p.slots, r), t.lead) + " "
	}
	if t.folded {
		// Too narrow for a pair: the destination stacks under its source,
		// indented to the source's column and free to use the rest of the line.
		indent := t.gutter + lipgloss.Width(lead)
		dest := m.th.stylePath(truncateMiddle(r.Dest, max(p.width-indent-2, 6)), style)
		return m.marker(selected) + lead + src + "\n" +
			strings.Repeat(" ", indent) + m.th.subtle.Render("→ ") + dest
	}

	row := m.marker(selected) + lead + padTo(src, t.primary) +
		m.th.subtle.Render(" → ") +
		padTo(m.th.stylePath(truncateMiddle(r.Dest, t.second), style), t.second)
	if t.counts > 0 {
		row += " " + padTo(m.countsCell(r), t.counts)
	}
	return row
}

// scopedRowView draws a row as "which root, which path beneath it", with a
// destination only when it is not the source path again. A row whose
// destination repeats its source therefore stays one line even in the folded
// layout, which is most of them.
func (m Model) scopedRowView(p plan, r MappingRow, selected bool) string {
	t := p.table
	sc := scopeOf(r)
	style := m.th.path
	if !r.Valid {
		style = m.th.invalid
	}
	if selected {
		style = style.Bold(true)
	}

	lead := ""
	if t.lead > 0 {
		lead = padTo(m.flagsCell(p.slots, r), t.lead) + " "
	}
	scopeStyle := m.th.accent
	if strings.Contains(sc.label, "→") {
		scopeStyle = m.th.subtle // a row that crosses scopes states both, quietly
	}
	head := m.marker(selected) + lead + padTo(scopeStyle.Render(fit(sc.label, t.scope)), t.scope) + "  "
	row := head + padTo(m.th.stylePath(truncateMiddle(sc.srcCell(), t.primary), style), t.primary)

	switch {
	case sc.dest == "":
		// Nothing to add: the destination is the source path under its own root.
	case t.folded:
		indent := strings.Repeat(" ", lipgloss.Width(head))
		dest := m.th.stylePath(truncateMiddle(sc.dest, max(p.width-lipgloss.Width(head)-2, 6)), style)
		row += "\n" + indent + m.th.subtle.Render("→ ") + dest
	default:
		row += m.th.subtle.Render(" → ") + padTo(m.th.stylePath(truncateMiddle(sc.dest, t.second), style), t.second)
	}
	if t.counts > 0 && !t.folded {
		if sc.dest == "" && t.second > 0 {
			row += strings.Repeat(" ", arrowWidth+t.second)
		}
		row += " " + padTo(m.countsCell(r), t.counts)
	}
	return row
}

func (m Model) flagsCell(slots []flagSlot, r MappingRow) string {
	cells := make([]string, 0, len(slots))
	for _, s := range slots {
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

func (m Model) changeRowView(p plan, c ChangeRow, selected bool) string {
	style := m.th.styleForKind(c.Kind)
	if selected {
		style = style.Bold(true)
	}
	tag := ""
	width := p.table.primary
	if c.Orphan {
		tag = m.th.subtle.Render(orphanTag)
		width = max(width-lipgloss.Width(orphanTag), minColumn)
	}
	path := m.th.stylePath(truncateMiddle(c.Path, width), style)
	return m.marker(selected) + style.Render(m.changeIcon(c.Kind)) + path + tag
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

func (m Model) configRowView(p plan, l configLine, selected bool) string {
	if l.section {
		return "  " + m.th.colHeader.Render(strings.ToUpper(l.key))
	}
	key := m.th.detailKey.Render(fit(l.key, p.table.lead))
	value := m.th.stylePath(truncateMiddle(l.value, p.table.primary), m.th.path)
	return m.marker(selected) + key + " " + value
}

// --- panels -----------------------------------------------------------------

// panelLine is one line of the detail or legend panel, kept as label + value so
// the panel's natural width can be measured before it is styled.
type panelLine struct {
	label   string
	value   string
	style   lipgloss.Style
	heading bool
	dim     bool // a continuation line, quieter than the value above it
}

// panelBody is the panel's content at its natural width. The layout plan
// measures it; panelView truncates it to the width it was given.
func (m Model) panelBody() []panelLine {
	if m.showLegend {
		return m.legendBody()
	}
	idxs := m.visible()
	if !m.showDetail || len(idxs) == 0 {
		return nil
	}
	idx := idxs[min(m.cursor[m.tab()], len(idxs)-1)]
	switch m.tab() {
	case tabChanges:
		return m.changeDetail(m.data.Changes[idx])
	case tabMappings:
		return m.mappingDetail(m.data.Mappings[idx])
	default:
		return nil
	}
}

func (m Model) legendBody() []panelLine {
	lines := []panelLine{{value: "LEGEND", heading: true}}
	for _, s := range m.slots {
		lines = append(lines, panelLine{label: s.glyph, value: fit(s.name, 8) + " " + s.help, style: s.style})
	}
	for _, k := range []struct {
		icon  string
		style lipgloss.Style
		text  string
	}{
		{m.data.Icons.DiffCreated, m.th.added, "created in the destination"},
		{m.data.Icons.DiffUpdated, m.th.modified, "content differs, will be overwritten"},
		{m.data.Icons.DiffRemoved, m.th.removed, "removed from the destination"},
	} {
		lines = append(lines, panelLine{label: strings.TrimSpace(k.icon), value: fit("", 8) + " " + k.text, style: k.style})
	}
	if m.tab() == tabMappings && m.scopedRows() >= 2 {
		lines = append(lines,
			panelLine{value: fit("scope", 8) + " the root both paths live under, e.g. config = $XDG_CONFIG_HOME ↔ $XDG_CONFIG_HOME_MIRROR"},
			panelLine{value: fit("a → b", 8) + " the two sides live under different roots", dim: true},
			panelLine{value: fit("(blank)", 8) + " the destination is the same path under its own root", dim: true},
		)
	}
	return lines
}

func (m Model) mappingDetail(r MappingRow) []panelLine {
	lines := []panelLine{{label: "src", value: r.RealSrc}, {label: "dest", value: r.RealDest}}
	if !r.Valid {
		lines = append(lines, panelLine{label: "invalid", value: r.InvalidReason + " · fix: " + r.InvalidFix, style: m.th.invalid})
	}
	if r.Force {
		lines = append(lines, panelLine{label: "force", value: "the destination is overwritten from the source"})
	}
	if len(r.OnlyPatterns) > 0 {
		lines = append(lines, panelLine{label: "only", value: strings.Join(r.OnlyPatterns, ", ")})
	}
	if len(r.IgnorePatterns) > 0 {
		lines = append(lines, panelLine{label: "ignore", value: strings.Join(r.IgnorePatterns, ", ")})
	}
	for i, h := range r.HookCommands {
		label := "hooks"
		if i > 0 {
			label = ""
		}
		lines = append(lines, panelLine{label: label, value: h})
	}
	if r.Changes() > 0 {
		lines = append(lines, panelLine{label: "changes", value: fmt.Sprintf("%d added, %d modified, %d removed", r.Added, r.Modified, r.Removed)})
	}
	return lines
}

func (m Model) changeDetail(c ChangeRow) []panelLine {
	kind := map[Kind]string{KindAdded: "added", KindModified: "modified", KindRemoved: "removed"}[c.Kind]
	if c.Orphan {
		kind += " (orphan: tracked by a previous pull, no longer matched)"
	}
	return []panelLine{
		{label: "path", value: c.Path},
		{label: "change", value: kind},
		{label: "mapping", value: c.Mapping},
	}
}

// natural is the panel line's unwrapped width, used to size the panel.
func (l panelLine) natural(labelWidth int) int {
	if l.heading {
		return lipgloss.Width(l.value)
	}
	return labelWidth + 1 + lipgloss.Width(l.value)
}

func labelWidth(lines []panelLine) int {
	w := 0
	for _, l := range lines {
		if !l.heading {
			w = max(w, lipgloss.Width(l.label))
		}
	}
	return w
}

func (m Model) panelView(p plan) string {
	body := m.panelBody()
	if len(body) == 0 {
		return ""
	}
	inner := max(p.panelWidth-4, minColumn) // the border and its padding
	lw := labelWidth(body)
	rendered := make([]string, 0, len(body))
	for _, l := range body {
		if l.heading {
			rendered = append(rendered, m.th.colHeader.Render(fit(l.value, inner)))
			continue
		}
		style := l.style
		if style.String() == "" {
			style = m.th.detailKey
		}
		valueStyle := m.th.path
		if l.dim {
			valueStyle = m.th.subtle
		}
		value := m.th.stylePath(truncateMiddle(l.value, max(inner-lw-1, minColumn)), valueStyle)
		rendered = append(rendered, style.Render(fit(l.label, lw))+" "+value)
	}
	panel := m.th.panel.Width(p.panelWidth - 2)
	if p.panel == panelBeside {
		panel = panel.MarginLeft(1)
	}
	return panel.Render(strings.Join(rendered, "\n"))
}

// --- footer -----------------------------------------------------------------

// footerLines is the key hints, fitted to the width: the full list when it fits
// beside the apply hint, a shorter list when it does not, and the hint on its
// own line when even that is too wide. The hint never drops — it is the answer
// to "how do I make this happen?".
func (m Model) footerLines(width int) []string {
	long := strings.Join([]string{"j/k move", "/ filter", "l legend", "d detail", "tab switch", "q quit"}, sep)
	short := strings.Join([]string{"j/k", "/ filter", "l legend", "q quit"}, sep)

	hint := ""
	if m.data.ShowChanges && len(m.data.Changes) > 0 {
		hint = "preview only: run with --apply to sync"
	}
	if hint == "" {
		for _, keys := range []string{long, short} {
			if lipgloss.Width(keys) <= width {
				return []string{keys}
			}
		}
		return []string{fit(short, width)}
	}
	for _, keys := range []string{long, short} {
		if lipgloss.Width(keys)+lipgloss.Width(sep)+lipgloss.Width(hint) <= width {
			return []string{keys + sep + hint}
		}
	}
	if lipgloss.Width(short) <= width {
		return []string{short, fit(hint, width)}
	}
	return []string{fit(hint, width)}
}

// footerHeight is how many rows the footer will take, so the layout plan can
// budget for it before it is rendered.
func (m Model) footerHeight(width int) int { return len(m.footerLines(width)) }

func (m Model) footerView(p plan) string {
	if m.filtering {
		return m.filter.View()
	}
	if q := strings.TrimSpace(m.filter.Value()); q != "" {
		return m.th.footerKey.Render("filter: ") +
			m.th.path.Render(q) +
			m.th.subtle.Render(fmt.Sprintf("  %d/%d  (esc to clear)", len(m.visible()), m.total()))
	}
	lines := m.footerLines(p.content)
	for i, l := range lines {
		lines[i] = m.th.footer.Render(l)
	}
	return strings.Join(lines, "\n")
}

// --- block helpers ----------------------------------------------------------

// padLines pads a block out to n lines so the chrome below it stays where the
// layout put it.
func padLines(block string, n int) string {
	if missing := n - lipgloss.Height(block); missing > 0 {
		return block + strings.Repeat("\n", missing)
	}
	return block
}

// clipWidth truncates every line of a block to width columns, counting printable
// cells rather than bytes so styling survives.
func clipWidth(block string, width int) string {
	rows := strings.Split(block, "\n")
	for i, r := range rows {
		if lipgloss.Width(r) > width {
			rows[i] = ansi.Truncate(r, width, "")
		}
	}
	return strings.Join(rows, "\n")
}

// clipLines truncates a block to n lines, which is how a panel gives up space
// it was not granted.
func clipLines(block string, n int) string {
	if n <= 0 || block == "" {
		return block
	}
	rows := strings.Split(block, "\n")
	if len(rows) <= n {
		return block
	}
	return strings.Join(rows[:n], "\n")
}

// Compile-time assurance that the cockpit satisfies tea.Model.
var _ tea.Model = Model{}
