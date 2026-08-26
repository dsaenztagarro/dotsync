package tui

import (
	"strconv"

	"github.com/charmbracelet/lipgloss"

	"github.com/dsaenztagarro/dotsync/internal/paths"
	"github.com/dsaenztagarro/dotsync/internal/render"
)

// theme holds every style the cockpit draws with. Base tones are adaptive so
// the screen is legible on light and dark terminals; the three change colors
// come from the config's [colors] table, so a user's overrides carry over from
// the classic renderer.
type theme struct {
	title       lipgloss.Style
	subtle      lipgloss.Style
	accent      lipgloss.Style
	tabActive   lipgloss.Style
	tabInactive lipgloss.Style
	colHeader   lipgloss.Style
	cursor      lipgloss.Style
	selected    lipgloss.Style
	path        lipgloss.Style
	envVar      lipgloss.Style
	invalid     lipgloss.Style
	force       lipgloss.Style
	only        lipgloss.Style
	ignore      lipgloss.Style
	hook        lipgloss.Style
	added       lipgloss.Style
	modified    lipgloss.Style
	removed     lipgloss.Style
	panel       lipgloss.Style
	detailKey   lipgloss.Style
	footer      lipgloss.Style
	footerKey   lipgloss.Style
	rule        lipgloss.Style
}

var (
	subtleColor = lipgloss.AdaptiveColor{Light: "245", Dark: "241"}
	accentColor = lipgloss.AdaptiveColor{Light: "62", Dark: "111"}
	errorColor  = lipgloss.AdaptiveColor{Light: "160", Dark: "203"}
	warnColor   = lipgloss.AdaptiveColor{Light: "130", Dark: "214"}
	okColor     = lipgloss.AdaptiveColor{Light: "28", Dark: "114"}
	textColor   = lipgloss.AdaptiveColor{Light: "236", Dark: "252"}
)

func newTheme(c render.Colors) theme {
	base := lipgloss.NewStyle()
	return theme{
		title:       base.Bold(true).Foreground(accentColor),
		subtle:      base.Foreground(subtleColor),
		accent:      base.Foreground(accentColor),
		tabActive:   base.Bold(true).Foreground(accentColor).Underline(true),
		tabInactive: base.Foreground(subtleColor),
		colHeader:   base.Bold(true).Foreground(subtleColor),
		cursor:      base.Bold(true).Foreground(accentColor),
		selected:    base.Bold(true).Foreground(textColor),
		path:        base.Foreground(textColor),
		envVar:      base.Foreground(lipgloss.Color(strconv.Itoa(paths.EnvVarsColor))),
		invalid:     base.Foreground(errorColor),
		force:       base.Foreground(warnColor),
		only:        base.Foreground(accentColor),
		ignore:      base.Foreground(subtleColor),
		hook:        base.Foreground(okColor),
		added:       base.Foreground(color256(c.Additions)),
		modified:    base.Foreground(color256(c.Modifications)),
		removed:     base.Foreground(color256(c.Removals)),
		panel:       base.Border(lipgloss.RoundedBorder()).BorderForeground(subtleColor).Padding(0, 1),
		detailKey:   base.Foreground(subtleColor),
		footer:      base.Foreground(subtleColor),
		footerKey:   base.Bold(true).Foreground(accentColor),
		rule:        base.Foreground(subtleColor),
	}
}

// color256 maps a config color index onto a lipgloss color, falling back to the
// terminal's default foreground when the index is unset.
func color256(idx int) lipgloss.TerminalColor {
	if idx <= 0 {
		return lipgloss.NoColor{}
	}
	return lipgloss.Color(strconv.Itoa(idx))
}

// styleForKind returns the style a change row is drawn with.
func (t theme) styleForKind(k Kind) lipgloss.Style {
	switch k {
	case KindAdded:
		return t.added
	case KindModified:
		return t.modified
	default:
		return t.removed
	}
}

// stylePath renders a path with its `$VAR` segments highlighted, the way the
// classic renderer colorizes them — but styled through lipgloss rather than
// with raw escapes, so widths stay measurable.
func (t theme) stylePath(p string, base lipgloss.Style) string {
	loc := paths.EnvVarSpans(p)
	if len(loc) == 0 {
		return base.Render(p)
	}
	var out string
	last := 0
	for _, m := range loc {
		out += base.Render(p[last:m[0]])
		out += t.envVar.Render(p[m[0]:m[1]])
		last = m[1]
	}
	return out + base.Render(p[last:])
}
