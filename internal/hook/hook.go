// Package hook runs a mapping's post-sync hooks. It ports Dotsync::HookRunner:
// each hook command is templated with {files}/{src}/{dest} and run via the
// shell, non-fatally, matching Open3.capture3.
package hook

import (
	"os/exec"
	"strings"

	"github.com/dsaenztagarro/dotsync/internal/model"
	"github.com/dsaenztagarro/dotsync/internal/paths"
	"github.com/dsaenztagarro/dotsync/internal/render"
)

// Runner executes or previews a mapping's hooks against a set of changed files.
type Runner struct {
	m            *model.Mapping
	changedFiles []string
	log          *render.Logger
	hookIcon     string
}

// NewRunner builds a hook Runner.
func NewRunner(m *model.Mapping, changedFiles []string, log *render.Logger, hookIcon string) *Runner {
	return &Runner{m: m, changedFiles: changedFiles, log: log, hookIcon: hookIcon}
}

// Preview returns the templated commands without running them.
func (r *Runner) Preview() []string {
	out := make([]string, 0, len(r.m.Hooks()))
	for _, cmd := range r.m.Hooks() {
		out = append(out, r.expand(cmd))
	}
	return out
}

// Execute runs each hook via `sh -c`, reporting success/failure but never
// aborting (hooks are non-fatal).
func (r *Runner) Execute() {
	for _, cmd := range r.m.Hooks() {
		r.run(r.expand(cmd))
	}
}

func (r *Runner) expand(command string) string {
	escaped := make([]string, 0, len(r.changedFiles))
	for _, f := range r.changedFiles {
		escaped = append(escaped, shellEscape(paths.SanitizePath(f)))
	}
	filesStr := strings.Join(escaped, " ")
	command = strings.ReplaceAll(command, "{files}", filesStr)
	command = strings.ReplaceAll(command, "{src}", r.m.Src())
	command = strings.ReplaceAll(command, "{dest}", r.m.Dest())
	return command
}

func (r *Runner) run(command string) {
	cmd := exec.Command("sh", "-c", command)
	var stderr strings.Builder
	cmd.Stderr = &stderr
	if err := cmd.Run(); err == nil {
		r.log.Info("Hook succeeded: "+command, r.hookIcon)
	} else {
		r.log.Error("Hook failed: " + command)
		if s := strings.TrimSpace(stderr.String()); s != "" {
			r.log.Error("  " + s)
		}
	}
}

// shellEscape reproduces Ruby's Shellwords.escape: characters outside the safe
// set are backslash-escaped, newlines are quoted, and the empty string becomes ”.
func shellEscape(s string) string {
	if s == "" {
		return "''"
	}
	var b strings.Builder
	for _, r := range s {
		switch {
		case r == '\n':
			b.WriteString("'\n'")
		case isShellSafe(r):
			b.WriteRune(r)
		default:
			b.WriteByte('\\')
			b.WriteRune(r)
		}
	}
	return b.String()
}

func isShellSafe(r rune) bool {
	switch {
	case r >= 'A' && r <= 'Z', r >= 'a' && r <= 'z', r >= '0' && r <= '9':
		return true
	default:
		return strings.ContainsRune("_-.,:+/@", r)
	}
}
