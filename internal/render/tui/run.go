package tui

import (
	"fmt"
	"io"
	"os"

	tea "github.com/charmbracelet/bubbletea"
)

// Enabled reports whether the cockpit should replace the classic renderer for
// this invocation. It is deliberately conservative: anything that is not a
// human at an interactive terminal — a pipe, a redirect, CI, a dumb terminal,
// an explicit opt-out — keeps the classic line output, which is the contract
// scripts and the differential parity harness depend on.
func Enabled(in, out *os.File, optOut bool) bool {
	return enabled(os.Getenv, isTerminal(in), isTerminal(out), optOut)
}

// enabled is the pure decision, split out so the rules are testable without a
// controlling terminal.
func enabled(env func(string) string, inTTY, outTTY, optOut bool) bool {
	switch {
	case optOut:
		return false
	case env("DOTSYNC_NO_TUI") != "":
		return false
	case env("CI") != "":
		return false
	case env("TERM") == "" || env("TERM") == "dumb":
		return false
	}
	return inTTY && outTTY
}

// isTerminal reports whether f is a character device (a terminal) rather than a
// pipe or a regular file.
func isTerminal(f *os.File) bool {
	if f == nil {
		return false
	}
	fi, err := f.Stat()
	return err == nil && fi.Mode()&os.ModeCharDevice != 0
}

// Run shows the cockpit, blocking until the user quits, then writes the
// one-line summary to out — the alt-screen is restored on exit, so that line is
// what remains in the scrollback.
func Run(d Data, out io.Writer) error {
	p := tea.NewProgram(New(d), tea.WithAltScreen())
	final, err := p.Run()
	if err != nil {
		return err
	}
	if m, ok := final.(Model); ok && m.Quitting() {
		fmt.Fprintln(out, d.Summary())
	}
	return nil
}
