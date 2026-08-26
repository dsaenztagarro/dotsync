# The TUI cockpit

*How the interactive screen behind `dotsync status` and the preview commands actually works today.* Complementary to [ADR 0003](decisions/0003-interactive-tui-as-an-additive-tty-only-layer.md), which records *why* it is TTY-only and read-only; this records *how* it behaves so the mental model can be rebuilt without reading all the code.

## The mental model

The cockpit is a **pure function of a snapshot**. Before the Bubble Tea program starts, the action layer converts the same `model.Mapping` and `engine.Diff` values the classic renderer prints into one flat `tui.Data` value; from that moment the screen neither reads the filesystem nor writes to it. Everything the user does — moving, filtering, switching tabs, opening the legend — is presentation state layered over that frozen snapshot, which is why the whole surface is testable by feeding key messages to a model and reading its `View()`.

The second idea: **the cockpit is one of three peers**, not a replacement. The classic line renderer, the cockpit, and the parity harness all consume the engine's data, and exactly one of the first two runs per invocation, decided before any output is produced.

## How it works

```
  config (TOML)                     internal/action
       |                       +--------------------------+
       v                       |  Execute()               |
  model.Mapping  -----------> |    opts.TUI ? ---------- + ------> executeTUI()
       |                       |       |                  |            |
       v                       |       no                 |         tuiData()
  engine.Diff    -----------> |       v                  |            |
                              |  classic sections        |            v
                              |  (render.Logger)         |        tui.Data  (snapshot)
                              +--------------------------+            |
                                                                      v
                                                      internal/render/tui: Bubble Tea
                                             Model.Init -> Update(msg) -> View() -> pty
                                                                      |
                                                       on quit: Data.Summary() -> stdout
```

**Which renderer runs** — `internal/cli/cli.go` decides, and both gates must open:

- `interactivePreview(opts)` — the run is a preview a human is watching: not `--apply`, not `--quiet`, not `--yes`.
- `tui.Enabled(stdin, stdout, --no-tui)` — `internal/render/tui/run.go`: stdin *and* stdout are character devices, `TERM` is set and is not `dumb`, `CI` and `DOTSYNC_NO_TUI` are unset, and `--no-tui` was not passed. The rules live in the unexported `enabled()` so they can be tested without a controlling terminal.

**The snapshot** — `internal/action/tui.go`:

- `tuiData()` assembles `tui.Data`: header facts (command, direction, config path), mapping rows, option and environment rows, and any destinations `--create-dest` created (as notices). It computes a diff **only** when the command's classic output has a differences section, so `status` stays a no-diff command and its cockpit has no Changes tab.
- `mappingRows()` flattens each mapping — the written `$VAR` form *and* the resolved path, the four flags, validity with its reason and fix, the `only`/`ignore` patterns, the hook commands, and the per-mapping change counts when a diff exists.
- `changeRows()` lists changes grouped additions → modifications → removals, sorted within each group (the classic order), each tagged with the mapping it came from; pull-side orphan removals come last, flagged `Orphan`.

**The screen** — `internal/render/tui/`:

- `data.go` — the view-model types and `Summary()`, the single line printed to stdout on exit (the alt-screen is torn down, so that line is all that survives).
- `model.go` — the Bubble Tea model. `Update` handles `WindowSizeMsg` and keys; while filtering, keys go to the `bubbles/textinput` instead of the navigation switch. `View` composes header, tab bar, optional column header, the row window, an optional panel (detail or legend), and the footer.
- `theme.go` — the lipgloss styles. Base tones are adaptive (light/dark); the three change colors come from the config's `[colors]` table and the flag glyphs from `[icons]`, so a user's overrides carry over from the classic renderer. `$VAR` segments are styled through lipgloss rather than the raw escapes `paths.ColorizeEnvVars` emits, so widths stay measurable — both share one definition of a variable via `paths.EnvVarSpans`.
- `text.go` — column geometry: middle-truncation that keeps roughly twice as much of a path's tail as its head (the filename is what the reader scans for), padding, and right-alignment.
- `run.go` — the activation predicate and the program runner (`tea.WithAltScreen`).

**Layout rules that make the screen degrade rather than break:**

| Pressure | What gives |
|---|---|
| Narrow terminal | paths middle-truncate with `…`; the key hints shorten, then drop to a second line, but the `--apply` hint never disappears |
| Short terminal | the detail pane yields first (`minRows` keeps rows on screen); an explicitly opened legend does not |
| More rows than fit | the last row line becomes a `row N of M` position indicator |
| A blanked-out icon (`icons.force = ""`) | that flag's column disappears; the remaining flags keep their own columns |

**The flag gutter** is why rows line up: each flag owns a fixed column, so a `force` glyph lands in the same place whether or not the row also has `only` or `ignore`. The classic renderer concatenates the glyphs instead, which is what shifted every following character and made the original output unreadable.

## Failure modes

- **Not a terminal** (pipe, redirect, CI, `TERM=dumb`) → `tui.Enabled` returns false; the classic renderer runs, byte-for-byte as before. This is the case the parity harness and every script hits.
- **`--apply`** → the cockpit is never reached; the prompt-driven classic path owns every mutation.
- **Zero width/height** (a pty opened without a size, as under `script` with a piped stdin) → the width clamps to 20 columns and rows still render, truncated.
- **A mapping whose destination is missing** → it renders in the error color with its reason and fix in the detail pane, and it is counted in the header so it cannot scroll out of sight.
- **The terminal cannot start** (`tea.Program.Run` error) → the error is returned to `main` and becomes a non-zero exit, like any other action error.
- **Stale snapshot** — the screen does not watch the filesystem; a change made while the cockpit is open is not reflected. Quit and re-run.

## See also

- [ADR 0003](decisions/0003-interactive-tui-as-an-additive-tty-only-layer.md) — the decision behind this mechanism
- [Design brief](../designs/briefs/shipped/status-cockpit.brief.md) — the surface, its states, and the key bindings
- [ADR 0002](decisions/0002-rewrite-in-go-as-a-single-binary.md) — the migration and its parity constraint
