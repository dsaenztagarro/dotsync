# Brief: status cockpit (interactive preview screen)

**Status:** shipped · **Surface:** `dotsync status`, and the preview mode of `dotsync diff` / `push` / `pull` (no `--apply`) · **Canvas:** ASCII mockups below (this project has no web surface; see [`../../DESIGN-SYSTEM.md`](../../DESIGN-SYSTEM.md)) · **Built in:** [ADR 0003](../../../architecture/decisions/0003-interactive-tui-as-an-additive-tty-only-layer.md) · [explainer](../../../architecture/tui-cockpit.md)

**complexity:** complex · **model:** Opus 5 (most capable) · **why:** a new presentation layer plus the non-TTY fallback boundary that keeps the classic output contract and the parity harness intact.

## Intent

Today `dotsync status` prints every mapping as one flat, unaligned line prefixed with bare ASCII flags (`!`, `>`, `x`, `?`) whose variable width pushes each row's `→` to a different column.
With a real config — 27 mappings — nothing lines up, the flags are unexplained unless `--legend` is passed, there is no count or summary anywhere, and the one invalid mapping is a footnote at the bottom of a screen that has already scrolled past.
The reader cannot answer the two questions they came for: *what is dotsync managing?* and *what is wrong right now?*

This brief covers the interactive replacement: a full-screen Bubble Tea cockpit that presents the same engine data as an aligned, scrollable, filterable table with a detail pane for the selected row.

## Scope

**In:**

- A single Bubble Tea program with tabs, driven by a view-model the action layer builds from the engine's data.
  `status` opens on **Mappings** (tabs: Mappings, Config); `diff` / `push` / `pull` in preview mode open on **Changes** (tabs: Changes, Mappings, Config).
- Scrolling, incremental filtering, a per-row detail pane, a legend overlay, and a one-line summary printed to stdout on exit (the alt-screen is restored, so the takeaway must survive it).
- Automatic fallback to the existing classic line renderer whenever the screen is not an interactive terminal, plus an explicit opt-out.

**Out:**

- Applying changes from inside the cockpit. The TUI is **read-only**: `--apply` keeps the classic prompt-driven path end-to-end. Mutating the filesystem from a screen whose selection semantics are new is a separate decision.
- `watch` (its own long-running surface), `setup`, and unified content diffs (`--diff-content`, still unimplemented).
- Any change to non-TTY output. Piped, redirected, and CI output stay byte-for-byte what they are today.

## States to cover

- **Default / populated** — mappings table with flag badges, per-mapping change counts, and the selected row expanded in the detail pane.
- **Empty** — a config with no mappings for this direction; a preview with no differences ("Everything is in sync").
- **Filtering** — `/` opens an input; the table narrows as the query is typed; the count in the header reflects matches; `esc` restores.
- **Invalid mappings** — rendered in the error color with the reason and the suggested fix in the detail pane, and surfaced in the header count so they cannot scroll away.
- **Any terminal size** — the frame reflows: see *Responsive layout* below.
- **Non-interactive** — not a TTY, `--apply`, `--quiet`, `--yes`, `CI`, `TERM=dumb`, or `DOTSYNC_NO_TUI=1`: the classic renderer, unchanged.

## Mockups

**Mappings tab** (`dotsync status`):

```
+------------------------------------------------------------------------------+
| dotsync status  ~/.config/dotsync.toml                push   27 mappings      |
|                                                       26 valid  1 invalid     |
+------------------------------------------------------------------------------+
|  Mappings | Config                                                            |
+------------------------------------------------------------------------------+
|   FLAGS   SOURCE                          DESTINATION                         |
| > !>      $XDG_CONFIG_HOME/nvim           $XDG_CONFIG_HOME_MIRROR/nvim        |
|           $HOME/.zshenv                   $HOME_MIRROR/.zshenv                |
|   >       $HOME/.ssh                      $HOME_MIRROR/.ssh                   |
|   ?       $XDG_CONFIG_HOME/cabal/config   $XDG_CONFIG_HOME_MIRROR/cabal/co…   |
+------------------------------------------------------------------------------+
| src     /Users/d/.config/nvim                                                 |
| dest    /Users/d/Mirror/.config/nvim                                          |
| force   destination is overwritten from source                                |
| only    *.lua, lua/**                                                         |
| hooks   nvim --headless "+Lazy! sync" +qa                                     |
+------------------------------------------------------------------------------+
| j/k move   / filter   l legend   tab switch   q quit                          |
+------------------------------------------------------------------------------+
```

**Changes tab** (`dotsync diff`), grouped and colored by kind:

```
+------------------------------------------------------------------------------+
| dotsync diff  ~/.config/dotsync.toml         push   12 changes                |
|                                                     5 added 4 modified 3 rem. |
+------------------------------------------------------------------------------+
|  Changes | Mappings | Config                                                  |
+------------------------------------------------------------------------------+
| > + $XDG_CONFIG_HOME_MIRROR/nvim/lua/plugins/new.lua                          |
|   + $HOME_MIRROR/.ssh/config.d/work                                           |
|   ~ $HOME_MIRROR/.zshenv                                                      |
|   - $XDG_CONFIG_HOME_MIRROR/nvim/lua/old.lua                    (orphan)      |
+------------------------------------------------------------------------------+
| Preview only - run with --apply to sync                                       |
+------------------------------------------------------------------------------+
```

**Filter** (`/`) and **legend** (`l`) replace the footer and the detail pane respectively; both are dismissed with `esc`.

## Responsive layout

The frame is resolved on every render from the measured content and the current terminal, not from a fixed grid — the rules and their rationale are [ADR 0004](../../../architecture/decisions/0004-resolve-the-layout-per-frame-from-content-and-viewport.md). Three shapes, and the thresholds are derived rather than chosen:

**Wide — the panel moves beside the list** (spare width >= 44 columns). Columns stay at their content width, so the arrow sits right after the longest source instead of at the middle of the screen:

```
dotsync status · PUSH · ~/.config/dotsync.toml
27 mappings · 26 valid · 1 invalid
──────────────────────────────────────────────────────────────────────────────────────────
 Mappings │ Config
  FLAGS     SOURCE                          DESTINATION
▸ !   x     $XDG_CONFIG_HOME/nvim         → $XDG_CONFIG_HOME_MIRROR/nvim   +-------------+
      >     $HOME/.ssh                    → $HOME_MIRROR/.ssh              | src  /Users |
            $HOME/.zshenv                 → $HOME_MIRROR/.zshenv           | dest /Users |
          ? $XDG_CONFIG_HOME/cabal/config → $XDG_CONFIG_HOME_MIRROR/cabal… | force ...   |
                                                                          +-------------+
j/k move · / filter · l legend · d detail · tab switch · q quit
```

**Comfortable — the panel stacks under the list**, hugging the last row rather than floating at the bottom of a tall screen:

```
  FLAGS     SOURCE                          DESTINATION
▸ !   x     $XDG_CONFIG_HOME/nvim         → $XDG_CONFIG_HOME_MIRROR/nvim
      >     $HOME/.ssh                    → $HOME_MIRROR/.ssh
+----------------------------------------------------------------------+
| src   /Users/d/.config/nvim                                           |
+----------------------------------------------------------------------+
```

**Narrow — the row folds** (under 64 columns for the path pair), the way a table becomes cards on a phone:

```
▸ !   x   $XDG_CONFIG_HOME/nvim
          → $XDG_CONFIG_HOME_MIRROR/nvim
      >   $HOME/.ssh
          → $HOME_MIRROR/.ssh
```

Under 12 rows the panel goes entirely; under 10, the header rule and column header go with it; the key hints shorten before they wrap. Whatever happens, a last-resort clip keeps the frame inside the terminal.

## Key bindings

| Key | Action |
| --- | --- |
| `j` / `k`, `down` / `up` | move the cursor |
| `pgdn` / `pgup`, `ctrl+d` / `ctrl+u` | page |
| `g` / `G`, `home` / `end` | first / last row |
| `tab` / `shift+tab` | next / previous tab |
| `/` | filter; `esc` clears and closes |
| `l` or `?` | toggle the legend |
| `d` or `enter` | toggle the detail pane |
| `q`, `esc`, `ctrl+c` | quit |

## Constraints

- **The engine renders nothing.** The cockpit consumes a view-model built by the action layer from the same `Mapping` / `Diff` values the classic renderer uses; no engine type learns about styling.
- **The classic contract is untouched.** Non-TTY output is unchanged, so the differential parity harness and any script parsing dotsync's output keep passing.
- **The user's `[colors]` and `[icons]` config still applies** — the cockpit reads the same palette and glyph set, so a Nerd Font icon set carries over.
- Degrade on a narrow or short terminal rather than wrapping into unreadability; never assume more than 80x24.

## Open questions

None blocking. Applying from the cockpit (`a` to sync the selection) is deliberately deferred — see [ADR 0003](../../../architecture/decisions/0003-interactive-tui-as-an-additive-tty-only-layer.md).

## As shipped

The implementation follows the brief, with the refinements real terminals argued for:

- Everything above about **responsive layout** — the first cut divided the viewport proportionally, which was unreadable on a 32" screen.
- When rows overflow, the last row line becomes a **`row N of M` position indicator**, and on a short terminal the **detail pane yields before the rows do**.
- The **key hints stay pinned to the bottom edge**; the detail panel does not.
