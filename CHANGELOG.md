# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Versioning continues the line of the original Ruby gem (now [`dotsync-ruby`](https://github.com/dsaenztagarro/dotsync-ruby), last released at 0.4.6): this binary reads the same configuration and reproduces the same behavior, so it is a continuation of the same tool rather than a new one.

## [0.5.0] - 2026-08-27

The Ruby gem rewritten as a single self-contained Go binary, with an interactive terminal cockpit on top of the ported behavior. Behavioral parity with the Ruby original is verified by a differential harness; non-interactive output is unchanged.

### Added

- **Go implementation of the whole tool** — `paths` (Ruby `PathUtils` semantics), `fsutil`, `model` (`Mapping` matching with a Ruby-compatible `fnmatch`), `engine` (`DirectoryDiffer`), `transfer` (atomic write, symlink preservation, type-conflict handling), `hook`, `manifest`, `config`, `render`, `action`, and a cobra `cli`.
- **`push`, `pull`, `diff`, `status`, `watch`, and `setup`/`init` commands** with the Ruby flag surface, including the deprecated no-op flags and the exit-code contract.
- **Live-sync daemon** (`watch`) built on fsnotify with recursive watching.
- **Interactive cockpit** for `status` and for `diff`/`push`/`pull` in preview mode: aligned mappings with one column per flag, counts in the header, scrolling, incremental filtering, a per-row detail pane, a legend, and a one-line summary printed on exit. Tabs are Mappings/Config for `status`, and Changes/Mappings/Config for the preview commands.
- **`--no-tui` flag and `DOTSYNC_NO_TUI` environment variable** to force classic line output.
- **Differential parity harness** (`script/parity.sh`) running the Ruby oracle and the Go binary over a shared fixture corpus.
- **CI gate** on Linux and macOS: `gofmt`, `go vet`, `go test`, `go build`.

### Changed

- **The cockpit resolves its layout per frame** from the measured content and the terminal size: columns are sized to their content, the detail panel moves beside the list when there is room and stacks below when there is not, rows fold onto two lines on narrow terminals, and decoration yields before content on short ones.
- **The Marshal config cache is dropped**; `DOTSYNC_NO_CACHE` is accepted as a no-op.
- **Default icons are ASCII**, so output is legible on terminals without a Nerd Font; `[icons]` and `[colors]` overrides apply to both renderers.

### Fixed

- **Mapping rows line up.** The classic renderer concatenates flag glyphs of varying width, which pushed each row's `→` to a different column; in the cockpit every flag owns a column.

### Removed

- **Automatic update checks** — the Ruby gem's once-a-day "new version available" notice is not implemented.

[0.5.0]: https://github.com/dsaenztagarro/dotsync/releases/tag/v0.5.0
