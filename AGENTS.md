# AGENTS.md

Instructions for AI agents working on this codebase. This is the single source of truth agents read before doing anything; keep it current.

## Model selection & task tracking

Every task you plan or pick up carries an explicit **complexity** rating and the **model** it runs on — state both (`complexity · model · why`) in the plan, the epic ticket, or the task list so the choice is deliberate and reviewable, not implicit. When you decompose work, tag each piece; don't leave the model a running default nobody chose.

- **Default to the most capable model.** Correctness-critical, interdependent, or context-heavy work — the path-matching/diff engine, the config deep-merge, anything where a subtle mistake breaks parity with the Ruby original — stays there even when it is large. Delegating hard work to a cheaper run because it's tedious is a false economy.
- **Escalate to a cheaper/faster model only when the complexity genuinely pays off there** and the task isn't the correctness-critical / interdependent / context-heavy kind above. When it's a close call, stay on the capable model.
- **Record the call, one clause of why.** e.g. `complexity: complex · model: <capable> · why: parity-critical glob semantics`. The rating is about consequence and coupling, not line count.

## Improving this workflow (raise the hand)

This project runs on the [ai-engineering-template](https://github.com/dsaenztagarro/ai-engineering-template). When you discover a **reusable, project-agnostic** improvement to the workflow itself — a rule that should exist here, a skill step that misfires, a docs-taxonomy gap, a principle worth stating — don't silently apply it only to this repo. **Raise the hand:** run the **`template-feedback`** skill (`.claude/skills/template-feedback/`) to surface a concrete proposal and, on the maintainer's OK, open an issue on the upstream template so every adopter benefits. Keep project-specific rules in this repo; send generalizable ones upstream.

## Project Overview

`dotsync` is a single, self-contained **Go** binary that synchronizes dotfiles between a machine and a mirror/repository, in either direction, with diff preview, backups, filtering, hooks, and a live-watch daemon. It has no runtime prerequisites — download the binary and run it on a fresh machine. See the [README](README.md).

This is the **Go rewrite** of the original Ruby gem (now at [`dsaenztagarro/dotsync-ruby`](https://github.com/dsaenztagarro/dotsync-ruby)). **Behavioral parity with the Ruby original is the governing constraint** during the migration: the Go binary must reproduce the Ruby tool's observable behavior (filesystem effects, exit codes, semantically-equivalent output). The rationale, alternatives, and phased plan are recorded in the ADRs under `docs/architecture/decisions/`.

## Tech Stack

- **Language:** Go (1.25+). Standard library first; zero runtime prerequisites in the shipped binary.
- **CLI:** cobra — the command tree, flag surface, and exit-code contract.
- **TUI:** bubbletea / lipgloss / bubbles (Charm) — the full-screen cockpit, shipped for `status` and the preview commands ([ADR 0003](docs/architecture/decisions/0003-interactive-tui-as-an-additive-tty-only-layer.md)).
- **Config:** BurntSushi/toml — parsed to a dynamic tree for deep-merge, then decoded.
- **Filesystem watch:** fsnotify/fsnotify — native FSEvents/inotify, walked recursively by `internal/action/watch.go` (the analog of Ruby's `listen`).
- **Release:** GoReleaser (planned) — cross-compiled archives, checksums, Homebrew tap, `curl | sh` installer.

## Common Commands

```bash
# build:   go build ./cmd/dotsync
# test:    go test ./...
# lint:    go vet ./... && gofmt -l .    # gofmt -l must print nothing
# run:     go run ./cmd/dotsync <command> [flags]
```

## Architecture

dotsync is layered so that **the engine computes data and renders nothing** — the single most important rule. Each consumer (the classic line renderer, the full-screen TUI, and the golden test harness) renders the same engine data structures. This keeps the TUI additive rather than a fork and keeps the non-interactive CLI contract intact.

```
              +-----------+     +--------+     +----------+
  config ---> |  model    | --> | engine | --> |  render  | --> stdout / TUI
  (TOML)      | (Mapping) |     | (Diff) |     | (classic |
              +-----------+     +--------+     |  + TUI)  |
                                   |           +----------+
                                   v
                              transfer (apply)
```

Key files (packages under `internal/`):

- `internal/paths` — path handling ported from Ruby `PathUtils`: `$(\w+)` env expansion, `~` expansion, darwin `/tmp`→`/private/tmp`, `$VAR` colorization.
- `internal/fsutil` — size-first content comparison and symlink-following stat helpers (`Exists`/`IsFile`/`IsDir`).
- `internal/model` — the domain: `Mapping` (include/ignore/skip/prune matching, validity, `manifest_key`, `apply_to`) and a Ruby-compatible `fnmatch` (default flags — no `FNM_PATHNAME`).
- `internal/engine` — `DirectoryDiffer`: source-index Set, subtree pruning, force-mode removals, ignore filtering; returns a `Diff`.
- `internal/transfer` — `FileTransfer`: atomic temp-write + rename, symlink preservation, type-conflict handling, empty-dir pruning.
- `internal/config` — TOML load, deep-merge (`include`), `source` indirection, `[sync.*]` shorthands.
- `internal/action` — orchestrates a run: sections, diffs, confirmation, backups, transfer, hooks; and builds the TUI's view-model (`tui.go`).
- `internal/cli` — cobra command tree, the flag/exit-code contract, and the TTY gate that picks the renderer.
- `internal/render` — the classic line renderer (palette, icons, `Logger`).
- `internal/render/tui` — the bubbletea cockpit: view-model, lipgloss theme, layout. Additive and TTY-only, so the classic output contract is untouched — see the [explainer](docs/architecture/tui-cockpit.md).
- `cmd/dotsync` — the binary entrypoint.

**Parity harness:** behavioral parity is verified by a golden/differential harness that runs the Ruby oracle and the Go binary against a shared fixture corpus and diffs filesystem state, exit codes, and (ANSI-stripped) output. See its explainer under `docs/architecture/` once built.

## Documentation Conventions

- **Architecture Decision Records** live in `docs/architecture/decisions/` — one decision per file, numbered, **immutable once accepted** (a changed decision is a new ADR that supersedes the old). Follow [`docs/architecture/decisions/template.md`](docs/architecture/decisions/template.md); the [README](docs/architecture/decisions/README.md) states the conventions. Record a decision that's architecturally meaningful (a data-model or interface contract, a cross-cutting integration choice, a parity/compatibility boundary) as an ADR — not local code choices.
- **How-to guides** live in `docs/guides/`; **feature docs** in `docs/features/`; **how-it-works explainers** in `docs/architecture/*.md`. Keep them distinct: an ADR is *why we chose X*, an explainer is *how it works today*, a guide is *how you do X*.
- **Markdown prose is one line per paragraph** (or semantic line breaks), never fixed-column hard wraps.

## Preserve Architectural Understanding

For any non-trivial mechanism — the diff engine's pruning/source-index scheme, the config deep-merge, the parity harness, the TUI event loop — keep a *how-it-works* explainer under `docs/architecture/` (a plain `*.md`). This is **complementary to ADRs, not a substitute**: the ADR records *why*; the explainer records *how it actually works today* so a maintainer (or a future agent) can rebuild the mental model without reverse-engineering the code.

- **When you build or materially change such a mechanism, write or update its explainer as part of the same work** — don't wait to be asked, and cross-link the explainer and its ADR both ways. Use [`docs/architecture/EXPLAINER-TEMPLATE.md`](docs/architecture/EXPLAINER-TEMPLATE.md).

## Documentation Style

When creating diagrams in documentation or code comments:
- Use simple ASCII characters (`+`, `-`, `|`, `v`, `^`, `>`) instead of Unicode box-drawing characters.
- This ensures consistent rendering across all fonts, terminals, and editors.

```
Good (ASCII):
+--------+     +--------+
| Box A  |---->| Box B  |
+--------+     +--------+
```

## Design workflow (the TUI cockpit)

dotsync's UI is a **terminal TUI** (the full-screen review-and-apply cockpit), not a web surface — so the HTML **Claude Design** canvas flow and a design-system binding do **not** apply here (`docs/designs/DESIGN-SYSTEM.md` is marked N/A). The lightweight part of the workflow still does:

1. **Brief.** A new or reworked TUI screen starts as a short **design brief** in `docs/designs/briefs/proposed/<name>.brief.md` (see [`docs/designs/README.md`](docs/designs/README.md)) — the surface, its states, key bindings, and intent, with an **ASCII mockup** standing in for the HTML canvas.
2. **Build to it.** Implement the screen against the brief; the TUI must degrade to the classic renderer on non-TTY / `--yes` / `--quiet` / piped / CI.
3. **Verify & promote.** Every interactive workflow the brief specifies gets a test; driving the runtime surface (an actual TTY session) is how fidelity is confirmed. When shipped, move the brief `proposed/ → shipped/`; a design decision worth keeping becomes an ADR.

If dotsync ever grows a genuine web surface, restore the full Claude Design flow from the template.

## Testing Guidelines

### Test the real thing; don't mock the object under test

A test that stubs the very thing it is checking proves the stub, not the app. Default to **real collaborators and fixtures**: build actual `Mapping`s over real temp directories, run the real diff/transfer, and assert on real filesystem outcomes. The existing `internal/**/*_test.go` files are seeded directly from the Ruby RSpec cases and run against `t.TempDir()` trees — extend that style.

Reserve test doubles for **genuine boundaries**, never the object under test or its in-process collaborators:
- **The network / external services** (e.g. the GitHub Releases version check).
- **Infrastructure you cannot stand up in a unit test.**
- **Forced-error injection you cannot otherwise reproduce** (e.g. permission/disk-full errors).

The tell for an over-coupled test: refactoring an implementation, without changing behavior, breaks the test. Rewrite it against real objects and observable outcomes.

### Verify the runtime surface

When a change has a runtime surface, **drive it and observe the behavior** before considering it done — passing tests are necessary, not sufficient. For parity-affecting changes, the golden/differential harness against the Ruby oracle is the authoritative check.

## CI / gate

Before a change ships, the following must be green (also what the `/epic` skill defers to):

- `gofmt -l .` prints nothing (all files formatted).
- `go vet ./...` passes.
- `go test ./...` passes.
- For parity-affecting changes: the golden/differential harness passes against the Ruby oracle.

## Development Workflow

For any new feature or significant change:

1. **Create a GitHub issue** documenting the change (summary, acceptance criteria, technical notes).
2. **Create a feature branch** named after the issue: `git checkout -b <issue>-<slug>`.
3. **Implement & test** — write tests alongside the change; run the gate frequently; drive the runtime surface.
4. **Record decisions** — architecturally meaningful decision → an ADR; new/changed mechanism → its explainer.
5. **Open a PR** with `gh pr create`, body ending `Closes #<issue>`; merge with `gh pr merge --squash` once the gate is green.

For larger, multi-ticket work, drive it with the **`/epic`** skill (`.claude/skills/epic/`): one design doc → a GitHub epic → phased sub-issues → shipped, one ticket at a time.
