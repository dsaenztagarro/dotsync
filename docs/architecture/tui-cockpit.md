# The TUI cockpit

*How the interactive screen behind `dotsync status` and the preview commands actually works today.* Complementary to [ADR 0003](decisions/0003-interactive-tui-as-an-additive-tty-only-layer.md), which records *why* it is TTY-only and read-only, and [ADR 0004](decisions/0004-resolve-the-layout-per-frame-from-content-and-viewport.md), which records *why* the layout is resolved per frame; this records *how* it behaves so the mental model can be rebuilt without reading all the code.

## The mental model

The cockpit is a **pure function of a snapshot**. Before the Bubble Tea program starts, the action layer converts the same `model.Mapping` and `engine.Diff` values the classic renderer prints into one flat `tui.Data` value; from that moment the screen neither reads the filesystem nor writes to it. Everything the user does — moving, filtering, switching tabs, opening the legend — is presentation state layered over that frozen snapshot, which is why the whole surface is testable by feeding key messages to a model and reading its `View()`.

The second idea: **the cockpit is one of three peers**, not a replacement. The classic line renderer, the cockpit, and the parity harness all consume the engine's data, and exactly one of the first two runs per invocation, decided before any output is produced.

The third: **nothing in the view layer knows a width.** Every frame begins by resolving a layout plan from the measured content and the current terminal size, and the view functions render that plan. A hardcoded column width would be a bug by construction, because it could not participate in the reflow.

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
- `layout.go` — the layout engine: the thresholds, `resolve()`, and the column/panel rules above.
- `text.go` — middle-truncation that keeps roughly twice as much of a path's tail as its head (the filename is what the reader scans for), padding, and fitting.
- `run.go` — the activation predicate and the program runner (`tea.WithAltScreen`).

**The layout plan** — `internal/render/tui/layout.go`, the single place where arrangement is decided:

```
  Model (content + state)          terminal size
          |                              |
          +-------------> resolve() <----+
                             |
                             v
                     plan {                        rendered by:
                       slots      flag columns  -> the row gutter
                       table      column widths -> rows + column header
                       rowHeight  1 or 2 lines  -> one- or two-line rows
                       rows       list lines    -> the row window
                       panel      beside/below/hidden
                       panelWidth, panelHeight  -> the detail or legend panel
                       content    total columns -> header rule, footer
                       colHeader, rule          -> decoration, dropped when short
                     }
```

`resolve` measures three things and applies the rules in [ADR 0004](decisions/0004-resolve-the-layout-per-frame-from-content-and-viewport.md):

1. **`activeSlots()`** — which flag columns any *visible* row actually carries; a config without hooks never pays for a hook column, and a filter narrows the gutter with the rows.
2. **`columns()`** — the natural width of each column (`contentNeeds()`), then `fitColumns()` to reconcile it with the viewport. Both columns fit: they keep their natural width and the remainder is left at the edge. Only one fits: it keeps its size, the other takes the rest. Neither: they split the difference. Under 64 columns for the pair, the destination stacks onto its own line and `rowHeight` becomes 2.
3. **`placePanel()` / `splitHeight()`** — the panel goes beside the list when 44+ columns are spare (sized to its own content, capped at 40% of the screen), below it otherwise, and nowhere at all under 12 rows. Vertically the list keeps `minRows`; a legend the user opened is clipped rather than dropped.

| Pressure | What gives |
|---|---|
| Wide terminal | the panel moves beside the list; columns stay at their content width, spare width is left at the edge |
| Narrow terminal | columns share the width, then the row folds into two lines, then the flag gutter is dropped |
| Short terminal | the header rule and column header go, then the detail pane, then the key hints shorten |
| More rows than fit | the last list line becomes a `row N of M` indicator |
| Any arithmetic slip | `clipWidth` / `clipLines` truncate the frame to the terminal rather than wrapping it |

**The flag gutter** is why rows line up: each flag owns a fixed column, so a `force` glyph lands in the same place whether or not the row also has `only` or `ignore`. The classic renderer concatenates the glyphs instead, which is what shifted every following character and made the original output unreadable.

## Failure modes

- **Not a terminal** (pipe, redirect, CI, `TERM=dumb`) → `tui.Enabled` returns false; the classic renderer runs, byte-for-byte as before. This is the case the parity harness and every script hits.
- **`--apply`** → the cockpit is never reached; the prompt-driven classic path owns every mutation.
- **Zero width/height** (a pty opened without a size, as under `script` with a piped stdin) → the width clamps to `minWidth` (24) and rows still render, folded and truncated.
- **A terminal too small for the chrome** (fewer rows than header + tabs + footer) → the frame is clipped to the terminal; the header survives, the list is what shrinks.
- **A mapping whose destination is missing** → it renders in the error color with its reason and fix in the detail pane, and it is counted in the header so it cannot scroll out of sight.
- **The terminal cannot start** (`tea.Program.Run` error) → the error is returned to `main` and becomes a non-zero exit, like any other action error.
- **Stale snapshot** — the screen does not watch the filesystem; a change made while the cockpit is open is not reflected. Quit and re-run.

## See also

- [ADR 0003](decisions/0003-interactive-tui-as-an-additive-tty-only-layer.md) — why the cockpit is additive, TTY-only, and read-only
- [ADR 0004](decisions/0004-resolve-the-layout-per-frame-from-content-and-viewport.md) — why the layout is resolved per frame
- [Design brief](../designs/briefs/shipped/status-cockpit.brief.md) — the surface, its states, and the key bindings
- [ADR 0002](decisions/0002-rewrite-in-go-as-a-single-binary.md) — the migration and its parity constraint
