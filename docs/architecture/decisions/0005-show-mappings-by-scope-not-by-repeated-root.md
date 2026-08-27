# 0005. Show mappings by scope, not by repeated root

**Status:** Accepted · **Scope:** presentation layer (`internal/render/tui`) · **Decision:** the cockpit's Mappings tab lifts each row's `$VAR` root into a scope column and shows the paths beneath it, drawing a destination only when it is not the source path again — while the classic renderer keeps printing both paths in full.

This records why the table stopped repeating information that is true of the whole table, and the rules that keep the shorter form honest.

## Context

Measured on a real 27-mapping config:

- `$XDG_CONFIG_HOME_MIRROR` appeared on more than 20 rows and distinguished none of them.
- **25 of 28 rows had an identical tail on both sides** — `$XDG_CONFIG_HOME/nvim → $XDG_CONFIG_HOME_MIRROR/nvim` — so the destination column was the source column again, spelled differently.
- The source column needed 42 columns to show paths whose informative part was at most 25.

The root is a property of the *table*, not of the row. Repeating it per row costs width on every screen, and costs a second line per row on a narrow one. dotsync's own configuration model already thinks in these terms: the `[sync.*]` shorthands are named `home`, `xdg_config`, `xdg_data`, `xdg_cache`, `xdg_bin`, and each expands to a `$X` / `$X_MIRROR` pair.

## Decision

The Mappings tab renders `FLAGS · SCOPE · PATH · DESTINATION`, where SCOPE names the root and PATH is what lives beneath it. `internal/render/tui/scope.go` derives it, and four rules keep the compression from lying:

1. **The scope cell describes the pair, not one side.** A single label is used only when both roots are twins — the same variable name modulo the `_MIRROR` suffix, which is exactly how the shorthands are defined. Anything else states both sides (`abs → config`, `config → data`, `DOTFILES → home`), so the display can never imply a symmetry that is not in the config.
2. **Known roots get a short name; everything else keeps its own.** `$XDG_CONFIG_HOME` → `config`, but `$DOTFILES` stays `DOTFILES` and a rootless path is `abs`. Two different roots can never collapse into one label.
3. **The destination is drawn only when it differs.** An empty cell means "the same path under its own root". A destination that *is* its root renders as `·`, so it can never be misread as unchanged. When no row differs, the column is not drawn at all.
4. **The column earns its width.** It appears only when at least two visible rows resolve to a scope; a config of absolute paths keeps the full-path rendering. This is the same rule the flag gutter follows.

Nothing is lost: the row's scope plus its path reconstruct the written form, the detail pane holds the resolved absolute paths, the Config tab lists every variable with its value, and the filter still matches the full written and resolved paths — typing `MIRROR` finds rows that no longer display it.

**The classic renderer is deliberately excluded.** It prints both paths in full, as it always has: it is the interface scripts and the differential parity harness consume, and parity with the Ruby original is the governing constraint of the migration ([ADR 0002](0002-rewrite-in-go-as-a-single-binary.md)).

## Alternatives considered

- **Leave it alone.** The information is technically all on screen. But a column that repeats the same 23 characters on 20 rows is not information, and it was the single largest consumer of width in the table.
- **Abbreviate the root instead (`$XCH/nvim`, `~/.ssh`).** Keeps the path syntactically whole and needs no new column. It trades a long token for a cryptic one, still repeats it per row, and invents abbreviations the user never wrote.
- **Group rows under scope headings** (`config (17)`, `home (5)`) instead of a column. Reads well and removes the repetition too, but it imposes an order on a list whose order is the config's, and it interacts badly with filtering, where a heading can outlive its rows. Worth revisiting as an optional grouping mode — the column is what it would be built on.
- **Derive the scope from `Mapping.SyncType()`** — the shorthands already carry `home`/`xdg_config`/… That covers only shorthand-derived mappings; explicit `[[push.mappings]]` entries have no sync type. Deriving from the written prefix covers both and matches what the user actually typed.
- **Apply the same compression to the classic renderer.** Consistent, and it would help piped output too — but it changes the bytes the parity harness compares and any script parsing that output. Rejected for the same reason the cockpit is TTY-only ([ADR 0003](0003-interactive-tui-as-an-additive-tty-only-layer.md)).

## Consequences

- **Easy:** reading a config at a glance — which scopes are in play, what lives in each, and the handful of mappings that actually rename something.
- **Easy:** narrow terminals. Under the folded layout a row only takes a second line when its destination differs, so most rows stay on one; the same config fits in roughly half the height it used to need.
- **Harder:** the row is now interpreted rather than literal. `config nvim` means "and the destination is the same path under the config mirror, because the header says PUSH". That is true for every row the rules allow to collapse, but it is a step away from showing exactly what the file says.
- **New obligation:** any future column that hides part of a path must keep it recoverable — through the scope label, the detail pane, or the filter — and must state both sides whenever they are not twins.
- **Open:** grouping and sorting by scope; a per-scope count in the header.

## References

- Issue [#3](https://github.com/dsaenztagarro/dotsync/issues/3) · PR [#4](https://github.com/dsaenztagarro/dotsync/pull/4)
- [ADR 0004](0004-resolve-the-layout-per-frame-from-content-and-viewport.md) — the layout engine this column plugs into
- Explainer: [`docs/architecture/tui-cockpit.md`](../tui-cockpit.md)
