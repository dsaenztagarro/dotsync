package tui

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

const ellipsis = "…"

// truncateMiddle shortens s to at most max columns by replacing its middle with
// an ellipsis, keeping roughly twice as much of the tail as of the head: for a
// path, the tail carries the filename and is what the reader is scanning for.
// Widths are counted in runes, which matches the character set paths use.
func truncateMiddle(s string, max int) string {
	if max <= 0 {
		return ""
	}
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	if max <= 1 {
		return ellipsis
	}
	head := (max - 1) / 3
	tail := max - 1 - head
	return string(r[:head]) + ellipsis + string(r[len(r)-tail:])
}

// fit truncates s to width columns and pads it out to exactly that width, so
// the next column starts in the same place on every row.
func fit(s string, width int) string {
	s = truncateMiddle(s, width)
	if pad := width - lipgloss.Width(s); pad > 0 {
		s += strings.Repeat(" ", pad)
	}
	return s
}

// padTo pads an already-styled cell (which may carry escape sequences) out to
// width using its printable width.
func padTo(styled string, width int) string {
	if pad := width - lipgloss.Width(styled); pad > 0 {
		return styled + strings.Repeat(" ", pad)
	}
	return styled
}

// spread lays left and right out on one line of the given width, pushing right
// against the far edge. If they do not both fit on one line, right is dropped.
func spread(left, right string, width int) string {
	gap := width - lipgloss.Width(left) - lipgloss.Width(right)
	if gap < 1 {
		return left
	}
	return left + strings.Repeat(" ", gap) + right
}
