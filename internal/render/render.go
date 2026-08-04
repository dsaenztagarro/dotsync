// Package render holds the classic (line-by-line) presentation layer: the
// user-overridable color palette and icon set, and a Logger that emits 256-color
// ANSI like the Ruby Dotsync::Logger. This is one of the three consumers of the
// engine's data (alongside the future TUI and the test harness); it renders,
// the engine does not.
package render

import (
	"fmt"
	"io"
	"os"
	"strings"
)

// Colors holds the 256-color indices for diff lines. Defaults mirror
// Dotsync::Colors; they are overridable via the config's [colors] table.
type Colors struct {
	Additions     int
	Modifications int
	Removals      int
}

// DefaultColors mirrors Dotsync::Colors defaults (34 / 36 / 88).
func DefaultColors() Colors { return Colors{Additions: 34, Modifications: 36, Removals: 88} }

// LoadColors applies [colors] overrides from the resolved config tree.
func LoadColors(raw map[string]any) Colors {
	c := DefaultColors()
	cm, ok := raw["colors"].(map[string]any)
	if !ok {
		return c
	}
	if v, ok := intFrom(cm["diff_additions"]); ok {
		c.Additions = v
	}
	if v, ok := intFrom(cm["diff_modifications"]); ok {
		c.Modifications = v
	}
	if v, ok := intFrom(cm["diff_removals"]); ok {
		c.Removals = v
	}
	return c
}

// Icons holds the glyphs prefixed to output. The Ruby defaults are Nerd Font
// code points; here the defaults are ASCII so output is legible on any terminal
// (the documented fallback set), and all are overridable via the [icons] table.
type Icons struct {
	Force       string
	Only        string
	Ignore      string
	Invalid     string
	Hook        string
	DiffCreated string
	DiffUpdated string
	DiffRemoved string
}

// DefaultIcons returns the ASCII fallback icon set.
func DefaultIcons() Icons {
	return Icons{
		Force:       "! ",
		Only:        "> ",
		Ignore:      "x ",
		Invalid:     "? ",
		Hook:        "@ ",
		DiffCreated: "+ ",
		DiffUpdated: "~ ",
		DiffRemoved: "- ",
	}
}

// LoadIcons applies [icons] overrides from the resolved config tree.
func LoadIcons(raw map[string]any) Icons {
	ic := DefaultIcons()
	im, ok := raw["icons"].(map[string]any)
	if !ok {
		return ic
	}
	set := func(key string, dst *string) {
		if s, ok := im[key].(string); ok {
			*dst = s
		}
	}
	set("force", &ic.Force)
	set("only", &ic.Only)
	set("ignore", &ic.Ignore)
	set("invalid", &ic.Invalid)
	set("hook", &ic.Hook)
	set("diff_created", &ic.DiffCreated)
	set("diff_updated", &ic.DiffUpdated)
	set("diff_removed", &ic.DiffRemoved)
	return ic
}

// Logger writes messages with optional 256-color ANSI, bold, and an icon
// prefix. When color is disabled (non-TTY or NO_COLOR) no escapes are emitted.
type Logger struct {
	w     io.Writer
	color bool
}

// NewLogger returns a Logger writing to w. When color is false, no ANSI escapes
// are emitted (for pipes/CI).
func NewLogger(w io.Writer, color bool) *Logger { return &Logger{w: w, color: color} }

// ColorEnabled reports whether ANSI should be emitted for f, honoring NO_COLOR
// and requiring a character device (TTY).
func ColorEnabled(f *os.File) bool {
	if _, ok := os.LookupEnv("NO_COLOR"); ok {
		return false
	}
	fi, err := f.Stat()
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeCharDevice != 0
}

// Log emits one line: optional color, optional bold, an icon prefix, the
// message, and a color reset. Mirrors Dotsync::Logger#log.
func (l *Logger) Log(msg string, color int, bold bool, icon string) {
	var b strings.Builder
	if l.color && color > 0 {
		fmt.Fprintf(&b, "\x1b[38;5;%dm", color)
	}
	if l.color && bold {
		b.WriteString("\x1b[1m")
	}
	b.WriteString(icon)
	b.WriteString(msg)
	if l.color && color > 0 {
		b.WriteString("\x1b[0m")
	}
	fmt.Fprintln(l.w, b.String())
}

// Print writes without a trailing newline (for interactive prompts).
func (l *Logger) Print(msg string) { fmt.Fprint(l.w, msg) }

// Plain writes an uncolored line.
func (l *Logger) Plain(msg string) { l.Log(msg, 0, false, "") }

// Info writes a bold info line (color 103).
func (l *Logger) Info(msg, icon string) { l.Log(msg, 103, true, icon) }

// Action writes a bold action line (color 153).
func (l *Logger) Action(msg, icon string) { l.Log(msg, 153, true, icon) }

// Error writes a bold error line (color 196).
func (l *Logger) Error(msg string) { l.Log(msg, 196, true, "") }

// Gray writes a dim hint line (color 240).
func (l *Logger) Gray(msg string) { l.Log(msg, 240, false, "") }

func intFrom(v any) (int, bool) {
	switch t := v.(type) {
	case int64:
		return int(t), true
	case int:
		return t, true
	case float64:
		return int(t), true
	}
	return 0, false
}
