# 0003. The interactive TUI is an additive, TTY-only, read-only layer

**Status:** Accepted · **Scope:** presentation layer (`internal/render`, `internal/action`, `internal/cli`) · **Decision:** the Bubble Tea cockpit replaces the classic renderer only for a human at an interactive terminal running a preview, and never applies changes; every other invocation keeps today's line output byte-for-byte.

This records where the boundary between the two renderers sits, and why the cockpit was given no power to mutate the filesystem. Both halves of that were live options, and both are load-bearing: one protects the parity contract the migration is being judged against, the other keeps the destructive path on the code that has been verified against the Ruby oracle.

## Context

`dotsync status` printed one flat line per mapping, prefixed with variable-width ASCII flags. On a 27-mapping config nothing aligned, the flags were unexplained without `--legend`, and the single invalid mapping was a footnote below a screen that had already scrolled past. The information was all there; the presentation made it unreadable.

Three constraints shaped the fix:

1. **Parity with the Ruby original is the governing constraint of the migration** ([ADR 0002](0002-rewrite-in-go-as-a-single-binary.md)). The differential harness runs both engines with piped stdout and diffs filesystem state, exit codes, and output. Anything that changes non-TTY output changes what the harness compares.
2. **Output is an interface.** `dotsync` is a dotfiles tool; it is run from scripts, from `watch`, and in CI. Changing what a pipe receives breaks consumers we cannot see.
3. **The layering rule**: the engine computes data and renders nothing, so each consumer — classic renderer, TUI, harness — is a peer that reads the same values ([`AGENTS.md`](../../../AGENTS.md)).

## Decision

The cockpit is **additive**. Two gates decide which renderer runs, and both must open:

```
  cli.run
    |
    +-- interactivePreview(opts)      -- not --apply, not --quiet, not --yes
    |     |
    +-- tui.Enabled(stdin, stdout)    -- both are TTYs, TERM is usable,
    |                                    not CI, not DOTSYNC_NO_TUI, not --no-tui
    v
  opts.TUI --> action.executeTUI --> tui.Run   (interactive, read-only)
         \
          `-> action.Execute ------> render.Logger lines   (unchanged contract)
```

- **TTY-only.** A pipe, a redirect, `CI`, `TERM=dumb`, `DOTSYNC_NO_TUI=1`, or `--no-tui` all fall back to the classic renderer. The parity harness, scripts, and CI are unaffected by construction, not by care.
- **Read-only.** `--apply` never reaches the cockpit. The transfer, backup, confirmation, orphan-cleanup, and hook-execution paths stay on the classic code that the harness verifies. The cockpit's own footer tells the user how to apply: re-run with `--apply`.
- **One screen, three tabs.** `status` opens on Mappings (Mappings, Config); `diff`/`push`/`pull` in preview mode open on Changes (Changes, Mappings, Config). The commands differ only in the snapshot they hand over, so there is one surface to maintain rather than one per command.
- **The action layer owns the view-model.** `action.tuiData()` converts `model.Mapping` and `engine.Diff` values into `tui.Data`; the TUI package never touches the filesystem, and the domain never learns about styling.
- **Charm stack.** bubbletea (event loop), lipgloss (styling and measurement), bubbles (the filter input) — the stack `AGENTS.md` already named for the cockpit.

## Alternatives considered

- **Restyle the classic renderer in place (aligned columns, colors, no event loop).** Simplest, and it would help piped output too — but it changes exactly the bytes the parity harness and user scripts compare, and it cannot solve the real problem on a long config: 27 rows plus a detail pane do not fit a screen without scrolling and filtering. Rejected as the primary fix; its useful half survives as the truncation and alignment logic inside the cockpit.
- **A TUI that also applies changes (`a` to sync the selection).** Attractive — it is the obvious next feature — but it would put a second, unverified path onto the destructive code while parity is still the governing constraint, and "apply what is selected" is a new semantic the Ruby tool has no equivalent for. Deferred deliberately; the read-only boundary is cheap to relax later and expensive to walk back.
- **Detect a TTY but keep the classic renderer as the default, with `--tui` to opt in.** Safest, and it makes the fix invisible: the readability problem is on the default path, so an opt-out (`--no-tui`) is the right polarity. The escape hatch remains for anyone who wants the old view interactively.
- **A separate `dotsync ui` command.** Keeps every existing command untouched, but splits the mental model in two and leaves `status` — the command people actually run to answer "what is dotsync managing?" — still unreadable.
- **Full-screen output for `watch` too.** Out of scope here: `watch` is a long-running stream of events rather than a snapshot, so it needs its own design rather than this one stretched.

## Consequences

- **Easy:** growing the cockpit (new tabs, sorting, per-row actions) without touching the engine or the classic renderer; keeping the harness green while the presentation changes.
- **Easy:** discovering what a config does — flags read vertically, counts are in the header, and the detail pane explains the selected row.
- **Harder:** two renderers now exist for the same data, so a new output section has to be added in both places, or deliberately in one. The view-model in `action/tui.go` is the seam that keeps this cheap.
- **New obligation:** anything that renders must keep working when it is *not* a TTY. New flags follow the same rule: shape the snapshot, never assume the screen.
- **Open:** applying from the cockpit; a `watch` surface; `--diff-content` (unified content diffs) as a detail-pane view once implemented.

## References

- Issue [#1](https://github.com/dsaenztagarro/dotsync/issues/1) — the tracking issue for the cockpit
- Design brief: [`docs/designs/briefs/shipped/status-cockpit.brief.md`](../../designs/briefs/shipped/status-cockpit.brief.md)
- Explainer: [`docs/architecture/tui-cockpit.md`](../tui-cockpit.md) — how the cockpit works today
- [ADR 0002](0002-rewrite-in-go-as-a-single-binary.md) — the migration whose parity constraint this decision protects
