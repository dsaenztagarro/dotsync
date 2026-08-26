# 0004. Resolve the cockpit's layout per frame from content and viewport

**Status:** Accepted · **Scope:** presentation layer (`internal/render/tui`) · **Decision:** every frame resolves a layout plan from the measured content and the current terminal size — columns size to content, the panel moves beside the list when there is room, rows split in two when there is not — instead of dividing the viewport proportionally.

The first cut of the cockpit divided the available width between source and destination. That is invisible at 80 columns and unusable at 236: on a 32" screen the arrow sat a hundred columns from the path it belonged to, the direction badge was two hundred columns from the title, and a two-line detail panel was stretched across the full width and pinned twenty blank rows below the row it described. This records the rules that replaced it.

## Context

A terminal is a viewport with no reflow of its own: unlike a browser, nothing wraps, centers, or scrolls unless the program does it. dotsync is run in every shape of terminal there is — a tmux split, a 24-row SSH session, a full-screen 32" display — and the same frame has to be legible in all of them.

Two failure modes bracket the problem:

- **Stretching.** Proportional columns turn spare width into gaps *inside* a row. The eye has to travel the gap to associate a source with its destination, and the association is the whole point of the row.
- **Clipping.** A fixed layout sized for 80 columns wastes a wide screen, and overflows a narrow one.

The content itself varies as much as the viewport: path lengths differ per config, filtering changes them mid-session, and the flag gutter is only as useful as the flags a config actually uses.

## Decision

`internal/render/tui/layout.go` holds one pure function — `Model.resolve() plan` — that measures the content and the viewport and returns the arrangement for that frame. The view functions render the plan; they make no layout decisions of their own, which is what makes the rules testable without a terminal.

**Horizontal**

| Rule | Behavior |
|---|---|
| Columns size to content | Source and destination take the longest path they hold (the CSS `max-content` idea). Width the content does not need is left at the edge, never pushed into the gap. |
| The panel is placed, not fixed | Spare width `>= 44` columns puts the detail/legend panel **beside** the list, top-aligned with the selection; otherwise it stacks below. |
| The panel is an aside | Its width is its own content, clamped to `[44, min(40% of the viewport, 100)]`. |
| Rows fold before they crush | When source and destination cannot share a line in `>= 64` columns, each row becomes two lines (`src`, then an indented `→ dest`) — the table-to-cards move. |
| The gutter earns its width | Only flags a visible row actually carries get a column; on a very narrow screen the gutter is dropped entirely, paths outrank it. |
| Nothing pins to a far edge | Direction and config path are inline with the title; the `--apply` hint follows the key hints; the header rule spans the *content*, not the viewport. |

**Vertical**

| Rule | Behavior |
|---|---|
| Decoration yields first | Under 10 rows the header rule and the column header are dropped. |
| The panel yields to the list | Under 12 rows there is no panel at all; otherwise the list keeps at least 4 lines and an oversized legend is clipped rather than allowed to squeeze it. |
| The panel hugs its list | A stacked panel sits directly under the last row, not at the bottom of a tall screen; only the key hints stay pinned to the bottom edge. |
| Overflow is visible | A list longer than its window ends in a `row N of M` indicator. |

Two last-resort guards close the loop: every line is truncated to the viewport width and the frame to its height, so an arithmetic slip degrades a frame instead of wrapping the terminal.

## Alternatives considered

- **Keep proportional columns, cap the total width.** One number to add, and it fixes the worst stretching. But it also freezes the layout: a 236-column screen renders the same 120-column frame as a laptop, and long paths still truncate while the screen sits empty. Rejected as a workaround for the real bug — sizing to the viewport instead of the content.
- **Cap and center the cockpit like a document.** Comfortable, symmetric, and genuinely good for prose. Paths are not prose: they are scanned in columns, and centering leaves the eye hunting for the left edge after every resize. It also spends the spare width on margins when there is information (the detail pane) that could occupy it.
- **A fixed two-pane split (e.g. 70/30).** Simple, and it looks right on the screen it was tuned for. It re-introduces the original bug in the other direction: a 30% panel is a wall of whitespace on a 236-column screen and unreadable on a 100-column one.
- **Horizontal scrolling for long paths.** Preserves every character, but a terminal list that scrolls sideways hides exactly the part of a path that identifies it. Middle-truncation with a preserved tail answers the same need without a mode.
- **Breakpoints keyed to fixed widths (`sm`/`md`/`lg`).** The familiar CSS approach, and the first thing tried. It does not work here: the same 100-column terminal is comfortable for `$HOME/.ssh` and cramped for a deep XDG path, so the thresholds have to be derived from the content, not from the device. The constants that remain are floors on legibility (a column below 12 columns, a panel below 44), not device classes.

## Consequences

- **Easy:** adding a column or a panel — declare its natural width and let `resolve` place it. Layout regressions are caught by tests that assert rules ("the arrow lands right after the longest source"), not by golden frames that break on any restyle.
- **Easy:** verifying the whole surface — a property test renders every viewport from 24x6 to 260x60 and asserts no line exceeds the width and no frame exceeds the height. It found two real overflows the day it was written.
- **Harder:** frames are no longer stable across states. Filtering re-measures the columns, so the table can shift width as the user types. That is the cost of sizing to content, and it is the behavior the user sees as "it fits".
- **New obligation:** anything that renders must take its widths from the plan. A hardcoded width in a view function is a bug by construction, because it cannot participate in the reflow.
- **Open:** per-tab layout preferences (a user who wants the panel always below), and remembering the panel state across runs.

## References

- Issue [#1](https://github.com/dsaenztagarro/dotsync/issues/1) · PR [#2](https://github.com/dsaenztagarro/dotsync/pull/2)
- [ADR 0003](0003-interactive-tui-as-an-additive-tty-only-layer.md) — the cockpit this layout belongs to
- Explainer: [`docs/architecture/tui-cockpit.md`](../tui-cockpit.md) — the mechanism as it works today
- Design brief: [`docs/designs/briefs/shipped/status-cockpit.brief.md`](../../designs/briefs/shipped/status-cockpit.brief.md)
