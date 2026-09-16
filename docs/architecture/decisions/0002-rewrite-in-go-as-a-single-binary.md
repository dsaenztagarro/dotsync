# 0002. Rewrite dotsync in Go as a single binary

**Status:** Accepted · **Scope:** Language, runtime, distribution · **Decision:** Reimplement dotsync as a single self-contained Go binary with a full-screen TUI, replacing the Ruby gem, and ship it via GitHub Releases while dual-shipping and then deprecating the gem.

This records why dotsync is being rewritten from Ruby to a compiled Go binary — the goals, the language evaluation, and the transition plan — so the choice is discoverable rather than reconstructed from commit history.

## Context

dotsync began as a Ruby gem. Two structural limits drove the rewrite:

1. **Distribution friction.** The gem is published only to RubyGems and requires a Ruby toolchain (MRI ≥ 3.2) preinstalled — on the exact fresh machine where you most want your dotfiles. There is no standalone binary, no Homebrew formula, no `curl | sh`.
2. **Runtime cost, especially for UI.** Ruby interpreter startup dominates: `--version`/`--help` was 900ms → 380ms only after aggressive lazy `require`s, and a Marshal config cache existed purely to dodge startup + parse cost. Any interactive/full-screen TUI on top of Ruby pays this tax on every launch and redraw. The changelog's recurring performance work (pull 7.2s → 0.6s; "eliminate redundant directory traversals") shows the maintainer already fighting the interpreter.

The goal: a single, statically-linked executable you download and run on a clean machine with zero prerequisites, single-digit-millisecond startup, hosting an **outstanding full-screen TUI**, while remaining a first-class non-interactive CLI for pipes/CI.

## Decision

Reimplement dotsync in **Go**.

- **TUI:** bubbletea / lipgloss / bubbles (Charm). The full-screen cockpit is the default on a TTY; the classic line renderer is the fallback for non-TTY / `--yes` / `--quiet` / piped / CI. The TUI is strictly additive — never required to complete a task.
- **CLI:** cobra, preserving the Ruby command set and flag surface (including deprecated no-op flags) and the exit-code contract.
- **Filesystem watch:** `rjeczalik/notify` (recursive, native FSEvents/inotify) — the analog of Ruby's `listen`.
- **Config:** BurntSushi/toml, parsed to a dynamic tree so `include` deep-merge is faithful, then decoded.
- **Distribution:** GoReleaser → cross-compiled archives + checksums + a Homebrew tap + a `curl | sh` installer, triggered on the existing `v*` tag convention.
- **The Marshal config cache is dropped.** A compiled binary parses this small TOML in sub-millisecond time, so the cache — and its whole class of mtime/size/version invalidation bugs — is unnecessary. `DOTSYNC_NO_CACHE` is accepted as a no-op for compatibility. The *runtime* optimizations (source-index set, subtree pruning, size-first compare) are preserved because they are algorithmic, not caching.

Behavioral parity with the Ruby original is the governing constraint during the port, verified by a golden/differential harness rather than a 1:1 port of the RSpec suite.

```
  Ruby gem (dotsync-ruby)                 Go binary (dotsync)
  ----------------------                  -------------------
  gem install dotsync        --dual-ship-->  brew install / curl | sh
  RubyGems distribution                    GitHub Releases
  ~380-900ms startup                       single-digit ms
  no standalone binary                     one file, no prerequisites
  line output only                         classic renderer + full-screen TUI
```

## Alternatives considered

- **Rust (ratatui + clap + notify + serde).** Close runner-up. Best startup/memory and compile-time correctness; `notify` is a near-drop-in for Ruby's `listen`. Rejected as the primary because, for a solo maintainer porting from Ruby, Go wins the decisive practical axes: the easiest cross-compilation, the smoothest port (GC removes ownership friction), and the most mature release tooling (GoReleaser). The sub-5ms startup edge is imperceptible for this tool. Choose Rust only if maximum startup/memory and compiler-enforced correctness outweigh iteration speed and port budget.
- **Crystal.** By far the lowest port effort (Ruby-like syntax). Rejected: no mature full-screen TUI framework and weak macOS static cross-compilation — it works against both hard goals (the TUI and the single self-contained binary).
- **Stay on Ruby, optimize further.** The startup floor and the Ruby prerequisite are inherent; no amount of lazy-loading removes the toolchain requirement or makes a redraw-heavy TUI cheap.
- **In-process strangler (swap Ruby internals for native code gradually).** Not viable from inside a gem; the realistic path is a clean-room rewrite delivered in phases behind the parity harness.

## Consequences

- **Enables** a zero-prerequisite install, fast startup, and headroom for a genuinely good TUI — exactly the goals.
- **Costs** a rewrite. The load-bearing engine is small (~500 lines) and ports cleanly; the weight is the ~8,300 lines of behavioral contract (handled by the golden harness, not a spec port) plus the net-new TUI.
- **New obligations:** the golden/differential harness (Ruby oracle vs Go) becomes the parity gate; a GoReleaser pipeline replaces the manual gem release; the self-update check must repoint from the RubyGems API to the GitHub Releases API.
- **Transition:** the Ruby repo is renamed `dotsync` → `dotsync-ruby` (kept active so it can ship a final deprecation release), its gemspec URLs repointed; the RubyGems gem name, the binary, the command, and `~/.config/dotsync.toml` are all unchanged. Archive `dotsync-ruby` only after sunset.
- **Open follow-ups:** the full-screen TUI, the watch daemon, `--diff-content` unified diffs, and byte-exact stdout parity for Nerd-Font icons (the Go default icon set is currently an ASCII fallback; the harness normalizes icons when comparing).

## References

- [`0001-record-decisions-as-adrs.md`](0001-record-decisions-as-adrs.md) — the ADR practice this follows.
- [ai-engineering-template](https://github.com/dsaenztagarro/ai-engineering-template) — the workflow scaffold this project adopts.
- `dsaenztagarro/dotsync-ruby` — the original Ruby implementation (the parity oracle).
- Explainer: [`docs/architecture/config-resolution.md`](../config-resolution.md) — how `source`, `include` and the deep-merge work today.
