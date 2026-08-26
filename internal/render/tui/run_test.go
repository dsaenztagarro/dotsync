package tui

import (
	"os"
	"strings"
	"testing"

	"github.com/dsaenztagarro/dotsync/internal/render"
)

func TestEnabledOnlyForAnInteractiveTerminal(t *testing.T) {
	term := map[string]string{"TERM": "xterm-256color"}
	with := func(extra map[string]string) map[string]string {
		out := map[string]string{"TERM": "xterm-256color"}
		for k, v := range extra {
			out[k] = v
		}
		return out
	}
	cases := []struct {
		name          string
		env           map[string]string
		inTTY, outTTY bool
		optOut        bool
		want          bool
	}{
		{"a human at a terminal", term, true, true, false, true},
		{"stdout redirected to a file or pipe", term, true, false, false, false},
		{"stdin fed from a pipe", term, false, true, false, false},
		{"--no-tui", term, true, true, true, false},
		{"DOTSYNC_NO_TUI set", with(map[string]string{"DOTSYNC_NO_TUI": "1"}), true, true, false, false},
		{"running in CI", with(map[string]string{"CI": "true"}), true, true, false, false},
		{"a dumb terminal", map[string]string{"TERM": "dumb"}, true, true, false, false},
		{"no TERM at all", map[string]string{}, true, true, false, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			env := func(k string) string { return c.env[k] }
			if got := enabled(env, c.inTTY, c.outTTY, c.optOut); got != c.want {
				t.Errorf("enabled = %v, want %v", got, c.want)
			}
		})
	}
}

func TestIsTerminalRejectsPipesAndFiles(t *testing.T) {
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	defer w.Close()
	if isTerminal(r) || isTerminal(w) {
		t.Error("a pipe is not a terminal")
	}
	if isTerminal(nil) {
		t.Error("a nil file is not a terminal")
	}

	f, err := os.CreateTemp(t.TempDir(), "out")
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if isTerminal(f) {
		t.Error("a regular file is not a terminal")
	}
}

// The alt-screen is torn down on exit, so the summary is the only thing left in
// the scrollback: it has to carry the counts on its own.
func TestSummaryCarriesTheTakeaway(t *testing.T) {
	d := Data{
		Command: "status",
		Mappings: []MappingRow{
			{Valid: true}, {Valid: true}, {Valid: false},
		},
		Colors: render.DefaultColors(),
		Icons:  render.DefaultIcons(),
	}
	got := d.Summary()
	for _, want := range []string{"status", "3 mappings", "2 valid", "1 invalid"} {
		if !strings.Contains(got, want) {
			t.Errorf("summary %q missing %q", got, want)
		}
	}
	if strings.Contains(got, "change") {
		t.Errorf("a command that did not diff should not mention changes: %q", got)
	}

	d.Command = "diff"
	d.ShowChanges = true
	d.Changes = []ChangeRow{{Kind: KindAdded}, {Kind: KindModified}, {Kind: KindRemoved}, {Kind: KindRemoved}}
	got = d.Summary()
	for _, want := range []string{"4 changes", "1 added", "1 modified", "2 removed"} {
		if !strings.Contains(got, want) {
			t.Errorf("summary %q missing %q", got, want)
		}
	}

	d.Changes = nil
	if got := d.Summary(); !strings.Contains(got, "no differences") {
		t.Errorf("summary %q should say there is nothing to do", got)
	}
}

func TestSummaryStaysSingularForOneMapping(t *testing.T) {
	d := Data{Command: "status", Mappings: []MappingRow{{Valid: true}}}
	if got := d.Summary(); !strings.Contains(got, "1 mapping,") {
		t.Errorf("summary %q should not pluralize a single mapping", got)
	}
}
