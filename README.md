# dotsync

[![CI](https://github.com/dsaenztagarro/dotsync/actions/workflows/ci.yml/badge.svg)](https://github.com/dsaenztagarro/dotsync/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/go-%3E%3D%201.25-blue)](https://go.dev/)

> Manage dotfiles like a boss — keep your dotfiles in sync across machines from a single TOML file.

`dotsync` is a single, self-contained **Go** binary for synchronizing dotfiles between a machine and a mirror/repository, in either direction, with diff preview, backups, filtering, hooks, and a live-watch daemon. It has no runtime prerequisites — download the binary and run it on a fresh machine.

This is the **Go rewrite** of dotsync. The original Ruby gem lives at [`dsaenztagarro/dotsync-ruby`](https://github.com/dsaenztagarro/dotsync-ruby) and remains installable via `gem install dotsync` during the transition. Behavioral parity with the Ruby original is the governing constraint of the migration; the rationale and phased plan are recorded in [`docs/architecture/decisions`](docs/architecture/decisions) ([ADR-0002](docs/architecture/decisions/0002-rewrite-in-go-as-a-single-binary.md)).

**Key Features:**

- **Bidirectional Sync Mappings**: Define once, sync both ways — eliminates config duplication with `[[sync.mappings]]` syntax.
- **XDG Shorthand DSL**: Concise `[[sync.home]]`, `[[sync.xdg_config]]`, `[[sync.xdg_data]]`, `[[sync.xdg_cache]]`, `[[sync.xdg_bin]]` syntax for common directory patterns.
- **Preview Mode**: See what changes would be made before applying them (dry-run by default).
- **Smart Filtering**: Use `force`, `only`, and `ignore` options — including glob patterns — to precisely control what gets synced.
- **Automatic Backups**: Pull operations create timestamped backups for easy recovery.
- **Live Watching**: Continuously monitor and sync changes in real time with the `watch` command.
- **Config Includes**: Compose configs from a shared base + machine-specific overlays with `include`.
- **Config Source**: Point local config to your dotfiles repo with `source` — changes are visible immediately without syncing.
- **Post-Sync Hooks**: Run commands automatically after files change (e.g. codesigning, chmod, service reload).
- **Interactive Screen**: On a terminal, `status` and the preview commands open a full-screen cockpit — aligned mappings, filtering, per-row detail, and a legend — and fall back to plain line output whenever the output is piped, quiet, or unattended.
- **Quiet by Default**: Minimal output by default — legends, mappings tables, and env vars are opt-in via `-v` or `--show-*` flags.
- **Invalid Paths Surface**: Broken mappings are reported in a dedicated, always-visible section with a clear reason and fix hint.
- **Auto-Create Destinations**: Missing destination directories can be created with `--create-dest`, or interactively per-mapping during `--apply`.
- **Customizable Output**: Override diff colors and status icons to match your terminal and preferences.
- **Zero Runtime Prerequisites**: A single static binary — no interpreter, no gems, nothing to install on the target machine.

## Table of Contents

- [Status](#status)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Trying it alongside the Ruby version](#trying-it-alongside-the-ruby-version)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Commands](#commands)
  - [Command Options](#command-options)
  - [Interactive Screen](#interactive-screen)
  - [Examples](#examples)
  - [Configuration](#configuration)
    - [Bidirectional Sync Mappings (Recommended)](#bidirectional-sync-mappings-recommended)
    - [Alternative: Unidirectional Mappings](#alternative-unidirectional-mappings)
    - [`force`, `only`, and `ignore` Options in Mappings](#force-only-and-ignore-options-in-mappings)
    - [Post-Sync Hooks](#post-sync-hooks)
    - [Config Includes](#config-includes)
    - [Config Source](#config-source)
    - [Environment Variables](#environment-variables)
  - [Safety Features](#safety-features)
    - [Invalid Paths and Auto-Create](#invalid-paths-and-auto-create)
    - [Confirmation Prompts](#confirmation-prompts)
    - [Automatic Backups](#automatic-backups)
    - [Preview Mode (Dry-Run)](#preview-mode-dry-run)
    - [Error Handling](#error-handling)
    - [Symlink Support](#symlink-support)
  - [Customizing Icons](#customizing-icons)
  - [Customizing Colors](#customizing-colors)
  - [Pro Tips](#pro-tips)
- [Common Use Cases](#common-use-cases)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [License](#license)

## Status

Under active migration from the Ruby implementation. The engine (path matching, directory diffing, file transfer), the configuration pipeline (`include`/`source`/deep-merge), and the `push`/`pull`/`diff`/`status`/`watch`/`setup` commands are ported and verified against the Ruby version by a differential parity harness. On top of that parity surface, `status` and the preview commands now render an [interactive screen](#interactive-screen) when you run them at a terminal.

Deliberately **not yet ported** (tracked for later phases):

- **Automatic update checks** — the Ruby gem's once-a-day "new version available" notice is not implemented in the Go binary.
- **Prebuilt binaries & installers** — GoReleaser archives, a Homebrew tap, and a `curl | sh` installer are planned; for now, build from source (see [Installation](#installation)).
- **`--diff-content`** — the flag is accepted for forward compatibility but does not yet render unified content diffs.
- **Applying from the interactive screen** — the cockpit is read-only by design; `--apply` runs the classic prompt-driven path (see [ADR 0003](docs/architecture/decisions/0003-interactive-tui-as-an-additive-tty-only-layer.md)).
- **An interactive surface for `watch`** — the live-sync daemon still streams classic lines.

## Requirements

- **Runtime:** none. The shipped binary is self-contained.
- **To build from source:** Go 1.25+.

## Installation

Prebuilt binaries are not published yet, so install from source.

**With `go install`** (drops a `dotsync` binary into `$(go env GOPATH)/bin`):

```sh
go install github.com/dsaenztagarro/dotsync/cmd/dotsync@latest
```

**From a clone:**

```sh
git clone https://github.com/dsaenztagarro/dotsync.git
cd dotsync
go build -o dotsync ./cmd/dotsync
./dotsync --version
```

### Trying it alongside the Ruby version

The Go binary reads the **same** configuration the Ruby gem does — `$DOTSYNC_CONFIG`, else `~/.config/dotsync.toml` — so it is a drop-in against your existing setup, and both tools default to a safe dry-run preview. To A/B test without disturbing your installed `dotsync`, run the Go build under a distinct name:

```sh
# From your clone, expose the build under a non-conflicting name on PATH:
ln -sf "$PWD/dotsync" ~/.local/bin/dotsync-go

dotsync-go status         # config + mappings, no diff
dotsync-go push           # dry-run preview, local -> mirror   (vs. `dotsync push`)
dotsync-go pull           # dry-run preview, mirror -> local
```

Nothing is written until you pass `--apply`. When you are ready to switch over, either put the Go binary earlier on your `PATH` than the Ruby one, or add `alias dotsync="$HOME/.local/bin/dotsync-go"` to your shell profile (`command dotsync` still reaches the Ruby gem for comparison).

> [!NOTE]
> The Go binary is **quiet by default** (only differences and invalid paths). The published Ruby gem prints the verbose sections by default. For an apples-to-apples comparison of output, add `-v` to the Go command.

## Quick Start

1. **Generate a starter configuration:**
   ```sh
   dotsync setup
   ```
   This writes `~/.config/dotsync.toml` with example mappings.

2. **Edit the configuration** (`~/.config/dotsync.toml`) to describe your dotfile mappings using bidirectional sync:
   ```toml
   # Sync your shell config
   [[sync.home]]
   path = ".zshenv"

   # Sync XDG config directories
   [[sync.xdg_config]]
   only = ["nvim", "alacritty", "zsh", "git"]
   force = true
   ```

3. **Preview your changes** (dry-run mode):
   ```sh
   dotsync pull   # Preview pulling from repo to local
   dotsync push   # Preview pushing from local to repo
   ```
   This shows what would change without modifying any files.

4. **Apply changes** when you are ready:
   ```sh
   dotsync pull --apply   # Apply repo -> local
   dotsync push --apply   # Apply local -> repo
   ```

## Usage

### Commands

> [!IMPORTANT]
> By default, both `push` and `pull` run in **preview mode** (dry-run): they show what would change without modifying any files. To apply changes you **must** pass `--apply` (`-a`).

- **push** — Transfer dotfiles from your local machine to the mirror/repository.
  ```sh
  dotsync push [flags]
  dotsync push --apply [flags]
  ```

- **pull** — Synchronize dotfiles from the mirror/repository to your local machine. `pull --apply` first writes a timestamped backup of the files it is about to overwrite (see [Automatic Backups](#automatic-backups)).
  ```sh
  dotsync pull [flags]
  dotsync pull --apply [flags]
  ```

- **watch** — Continuously monitor your mapping sources and live-sync changes local -> mirror until interrupted (Ctrl+C). It watches the source side of every valid `[[sync.*]]`/`[[push.mappings]]` mapping plus any `[[watch.mappings]]`, recursing into subdirectories and picking up newly created ones. It supports the same output flags as push/pull and honours `--create-dest` at startup, but never prompts interactively — the daemon loop must not block on input.
  ```sh
  dotsync watch [flags]
  ```

- **setup** (alias **init**) — Write a starter configuration file to `~/.config/dotsync.toml` (or the path given with `-c`).
  ```sh
  dotsync setup
  dotsync init
  ```

- **status** — Show the resolved configuration and mappings without diffing or touching the filesystem. On a terminal this opens the [interactive screen](#interactive-screen).
  ```sh
  dotsync status
  ```

- **diff** — Preview local -> mirror changes (a convenient alias for `push` in preview mode). On a terminal this opens the [interactive screen](#interactive-screen) on its **Changes** tab.
  ```sh
  dotsync diff
  ```

### Command Options

`push`, `pull`, `diff`, `status`, and `watch` accept the following flags.

**Sync options:**

- `-a, --apply` — Apply changes (without this, commands run in preview mode).
- `--dry-run` — Explicitly run in preview mode (the default; useful for clarity in scripts). If combined with `--apply`, `--dry-run` wins.
- `-y, --yes` — Skip confirmation prompts and auto-confirm (also skips the per-mapping prompt for creating missing destinations).
- `--create-dest` — Create any missing destination directories (see [Invalid Paths and Auto-Create](#invalid-paths-and-auto-create)).
- `--force-hooks` — Run post-sync hooks even when no files changed.
- `-c, --config PATH` — Use a custom config file path.

**Output control** (output is quiet by default — only the differences section and the always-visible invalid-paths section are shown):

- `-v, --verbose` — Show all sections (options, env vars, legends, mappings table).
- `-q, --quiet` — Suppress the differences section (invalid paths are still shown; also skips the confirmation prompt).
- `--legend` — Show the mappings and differences legends.
- `--show-mappings` — Show the mappings table.
- `--show-env` — Show the referenced environment variables.
- `--show-options` — Show the resolved options.
- `--only-config` — Show only the config/options and mappings (no differences).
- `--only-mappings` — Show only the mappings table.
- `--only-diff` — Show only the differences section (this is the default view).
- `--no-tui` — Print classic line output instead of the [interactive screen](#interactive-screen).

**General:**

- `--trace` — Print full error traces (for debugging).
- `--version` — Print the version.
- `-h, --help` — Show help for a command.

> [!NOTE]
> The pre-migration `--no-legend`, `--no-config`, `--no-mappings`, `--no-diff-legend`, and `--no-diff` flags are accepted as silent no-ops for backwards compatibility — those sections are hidden by default now, so the flags no longer do anything. `--diff-content` is likewise accepted but not yet implemented (see [Status](#status)).

### Interactive Screen

On an interactive terminal, `status`, `diff`, `push`, and `pull` (in preview mode) open a full-screen cockpit instead of printing lines: mappings in aligned columns, one column per flag, counts in the header, and a detail pane for whatever is selected.

```
dotsync status ~/.config/dotsync.toml                                        PUSH
27 mappings · 26 valid · 1 invalid
────────────────────────────────────────────────────────────────────────────────
 Mappings │ Config
  FLAGS     SOURCE                             DESTINATION
▸ !   x     $XDG_CONFIG_HOME/nvim            → $XDG_CONFIG_HOME_MIRROR/nvim
    >       $HOME/.ssh                       → $HOME_MIRROR/.ssh
          ? $XDG_CONFIG_HOME/cabal/config    → $XDG_CONFIG_HOME_MIRROR/cabal/…
            $HOME/.zshenv                    → $HOME_MIRROR/.zshenv
  row 1 of 27
╭──────────────────────────────────────────────────────────────────────────────╮
│ src      /home/you/.config/nvim                                              │
│ dest     /home/you/dotfiles/xdg_config_home/nvim                             │
│ force    the destination is overwritten from the source                      │
│ ignore   lazy-lock.json                                                      │
╰──────────────────────────────────────────────────────────────────────────────╯
j/k move · / filter · l legend · d detail · tab switch · q quit
```

`status` opens on **Mappings** (tabs: Mappings, Config). `diff`, `push`, and `pull` open on **Changes** — every pending addition, modification, and removal, grouped and colored like the classic output, with the owning mapping in the detail pane.

**Keys**

| Key | Action |
| --- | --- |
| `j` / `k`, `↓` / `↑` | move the cursor |
| `pgdn` / `pgup`, `ctrl+d` / `ctrl+u` | page |
| `g` / `G`, `home` / `end` | first / last row |
| `tab` / `shift+tab` | next / previous tab |
| `/` | filter rows; `esc` clears and closes |
| `l` or `?` | toggle the legend |
| `d` or `enter` | toggle the detail pane |
| `q`, `esc`, `ctrl+c` | quit (a one-line summary is printed on exit) |

The screen is **read-only** — it never writes to disk. When there are changes to apply, re-run with `--apply`, which always uses the classic prompt-driven output.

**When it does *not* open** (classic line output is used instead, unchanged):

- stdout or stdin is not a terminal — a pipe, a redirect, a subshell capture;
- `--apply`, `--quiet`, or `--yes` was passed;
- `--no-tui` or `DOTSYNC_NO_TUI=1`;
- `CI` is set, or `TERM` is unset or `dumb`.

Your `[icons]` and `[colors]` overrides apply to this screen too — see [Customizing Icons](#customizing-icons) and [Customizing Colors](#customizing-colors).

### Examples

```sh
# Setup and inspection
dotsync setup                      # Create the initial config file
dotsync init                       # Same as setup (alias)
dotsync status                     # View the resolved configuration

# Preview changes (dry-run, quiet by default)
dotsync pull                       # Preview pull changes
dotsync push                       # Preview push changes
dotsync diff                       # Quick preview (alias for push)
dotsync pull -v                    # Preview with full output (legends, mappings, env vars)
dotsync pull --show-mappings       # Quiet + add the mappings table

# Apply changes
dotsync pull --apply               # Apply; prompts to create missing destinations
dotsync pull --create-dest -ay     # Apply, auto-create missing dests, no prompts
dotsync push -ay                   # Apply without confirmation (--apply + --yes)

# Custom configuration files
dotsync -c ~/work-dotfiles.toml push
dotsync --config ~/.config/personal.toml pull

# Scripted / unattended
dotsync pull --apply --yes --create-dest -q

# Live sync
dotsync watch                      # Watch with default (quiet) output
dotsync watch -v                   # Watch with full startup output
dotsync watch --create-dest        # Create missing dests at startup, then watch
```

### Configuration

dotsync uses a TOML configuration file to define mappings between your local machine and your dotfiles repository. By default it reads `~/.config/dotsync.toml`; override the path with `$DOTSYNC_CONFIG` or the `-c/--config` flag. The recommended approach is **bidirectional sync mappings**, which eliminate duplication and keep the config clean.

> [!TIP]
> Set up mirror environment variables for a cleaner configuration:
> ```sh
> # Add to your ~/.zshrc or ~/.bashrc
> export DOTFILES_DIR="$HOME/Code/dotfiles"
> export XDG_CONFIG_HOME_MIRROR="$DOTFILES_DIR/xdg_config_home"
> export XDG_DATA_HOME_MIRROR="$DOTFILES_DIR/xdg_data_home"
> export HOME_MIRROR="$DOTFILES_DIR/home"
> ```

#### Bidirectional Sync Mappings (Recommended)

Use `[[sync]]` mappings to define paths that sync in both directions. This is the **preferred approach** because it eliminates duplication between push and pull configurations.

##### XDG Shorthand Syntax

The most concise way to define mappings for standard XDG directories:

```toml
# Sync home directory files
[[sync.home]]
path = ".zshenv"

# Sync multiple configs from XDG_CONFIG_HOME
[[sync.xdg_config]]
only = ["alacritty", "git", "zsh", "starship.toml"]
force = true

# Sync a specific config with custom options
[[sync.xdg_config]]
path = "nvim"
force = true
ignore = ["lazy-lock.json"]

# Sync XDG data directories
[[sync.xdg_data]]
path = "git"
force = true
```

**Supported shorthands:**

| Shorthand | Local | Remote |
|-----------|-------|--------|
| `sync.home` | `$HOME` | `$HOME_MIRROR` |
| `sync.xdg_config` | `$XDG_CONFIG_HOME` | `$XDG_CONFIG_HOME_MIRROR` |
| `sync.xdg_data` | `$XDG_DATA_HOME` | `$XDG_DATA_HOME_MIRROR` |
| `sync.xdg_cache` | `$XDG_CACHE_HOME` | `$XDG_CACHE_HOME_MIRROR` |
| `sync.xdg_bin` | `$XDG_BIN_HOME` | `$XDG_BIN_HOME_MIRROR` |

**Options:**

- `path` (optional): Relative path within the directory. If omitted, syncs the entire directory.
- `force`, `only`, `ignore`, `hooks`: All standard mapping options are supported.

##### Explicit Sync Syntax

For custom paths that do not follow XDG conventions, use explicit `[[sync.mappings]]` entries with `local` and `remote` keys:

```toml
[[sync.mappings]]
local  = "$XDG_CONFIG_HOME/nvim"
remote = "$XDG_CONFIG_HOME_MIRROR/nvim"
force  = true
ignore = ["lazy-lock.json"]

[[sync.mappings]]
local  = "$HOME/.zshenv"
remote = "$HOME_MIRROR/.zshenv"

# Sync the config file itself to a different name in the repo
[[sync.mappings]]
local  = "$XDG_CONFIG_HOME/dotsync.toml"
remote = "$XDG_CONFIG_HOME_MIRROR/dotsync/dotsync.macbook.toml"
```

**How it works:**

- `local` is your local machine path; `remote` is the path in your dotfiles repository.
- For **push**: `local` -> `remote`. For **pull**: `remote` -> `local`.
- All standard options (`force`, `only`, `ignore`, `hooks`) are supported.

#### Alternative: Unidirectional Mappings

For asymmetric scenarios where push and pull need different configurations, use separate `[[push.mappings]]`, `[[pull.mappings]]`, and `[[watch.mappings]]` sections with `src`/`dest` keys:

```toml
# Pull from repo to local (repo -> local)
[[pull.mappings]]
src  = "$XDG_CONFIG_HOME_MIRROR/nvim"
dest = "$XDG_CONFIG_HOME/nvim"
force = true
ignore = ["lazy-lock.json"]

# Push from local to repo (local -> repo)
[[push.mappings]]
src  = "$XDG_CONFIG_HOME/alacritty"
dest = "$XDG_CONFIG_HOME_MIRROR/alacritty"
only = ["alacritty.toml", "themes"]

# Watch-only target for live syncing
[[watch.mappings]]
src  = "$XDG_CONFIG_HOME/nvim"
dest = "$XDG_CONFIG_HOME_MIRROR/nvim"
```

> [!NOTE]
> You can mix `[[sync.mappings]]`, XDG shorthands, and `[[push/pull/watch.mappings]]` in the same file. Each command reads the `[[sync.*]]` mappings plus the mappings for its own direction (`push`/`pull`/`watch`). Use bidirectional sync for symmetric mappings and unidirectional for special cases.

#### `force`, `only`, and `ignore` Options in Mappings

Each mapping entry supports the following options.

##### `force`

A boolean. When `true`, files in the destination that do not exist in the source are **removed**, keeping the destination an exact mirror of the source. Combined with `only`, only files matching the `only` filter are managed (others are left untouched).

```toml
[[sync.xdg_config]]
path = "nvim"
force = true
ignore = ["lazy-lock.json"]
```

##### `only`

An array of relative paths or glob patterns to **selectively** transfer from the source. Paths are relative to the source directory; parent directories are created as needed; everything else in the source is skipped.

```toml
# Whole subdirectories
[[sync.xdg_config]]
only = ["nvim", "alacritty", "zsh"]

# Specific files
[[sync.xdg_config]]
path = "alacritty"
only = ["alacritty.toml", "rose-pine.toml"]

# Files inside nested directories (parents auto-created)
[[sync.xdg_config]]
only = ["bundle/config", "ghc/ghci.conf", "cabal/config"]

# Glob patterns
[[sync.home]]
path = "Library/LaunchAgents"
only = ["local.*.plist"]
```

Supported glob characters: `*` (any sequence), `?` (any single character), and `[charset]` (any character in the set). Globs can be mixed with exact paths in the same `only` array.

On **pull**, `only` mappings also clean up **orphans** — files a previous pull placed in the destination that are no longer in the source (and no longer match the filter) are removed, tracked via a small manifest. This does not apply when `force = true` (force already mirrors the whole directory).

##### `ignore`

An array of relative paths or patterns to **exclude** during transfer:

```toml
[[sync.xdg_config]]
path = "nvim"
ignore = ["lazy-lock.json", "plugin/packer_compiled.lua"]
```

Combining options:

```toml
[[sync.xdg_config]]
path = "nvim"
only = ["lua", "init.lua"]
ignore = ["lua/plugin/packer_compiled.lua"]
force = true
```

This transfers only `lua/` and `init.lua`, excludes `lua/plugin/packer_compiled.lua` even though it is under `lua/`, and removes destination files that are not in the source.

> [!NOTE]
> When `ignore` and `only` both match a path, `ignore` wins. These options apply when the source is a directory, for both `push` and `pull`.

#### Post-Sync Hooks

Hooks run shell commands automatically after a mapping's files are transferred. They execute only when files actually changed (unless `--force-hooks` is given) and only under `--apply`; in preview mode they are shown as a "Hooks to run" preview. A failing hook logs an error but never aborts the remaining hooks or mappings.

##### Hook Types

| Hook | Runs | Valid in |
|------|------|----------|
| `post_sync` | after sync in both directions | `[[sync.*]]` mappings |
| `post_push` | only after push | `[[sync.*]]` and `[[push.mappings]]` |
| `post_pull` | only after pull | `[[sync.*]]` and `[[pull.mappings]]` |

For `[[sync.*]]` mappings, hooks resolve by direction: **push** runs `post_sync` + `post_push`; **pull** runs `post_sync` + `post_pull`.

##### Template Variables

| Variable | Expands to |
|----------|------------|
| `{files}` | Shell-quoted paths of the changed destination files |
| `{src}` | The mapping's source path |
| `{dest}` | The mapping's destination path |

##### Examples

```toml
# Single command (shorthand mapping)
[[sync.xdg_bin]]
force = true
hooks = { post_sync = "codesign -s - {files}" }

# Multiple commands (explicit sync)
[[sync.mappings]]
local  = "$XDG_CONFIG_HOME/scripts"
remote = "$XDG_CONFIG_HOME_MIRROR/scripts"
hooks = { post_sync = ["codesign -s - {files}", "chmod 700 {files}"], post_pull = "launchctl kickstart -k gui/$(id -u)/com.example.service" }

# Unidirectional mapping with a table form
[[pull.mappings]]
src  = "$DOTFILES_DIR/scripts"
dest = "$HOME/Scripts"

[pull.mappings.hooks]
post_pull = ["codesign -s - {files}", "chmod 700 {files}"]
```

#### Config Includes

Use `include` to compose a config from a shared base file and a machine-specific overlay, eliminating duplication when multiple machines share most of their mappings.

```toml
# dotsync.mbp_personal.toml (overlay — only the delta)
include = "dotsync.base.toml"

[[sync.xdg_config]]
path = "claude"
only = ["settings.json", "instructions", "commands"]
```

```toml
# dotsync.base.toml (shared across all machines)
[[sync.home]]
path = ".zshenv"

[[sync.xdg_config]]
only = ["alacritty", "git", "nvim", "zsh"]
force = true
```

**Merge semantics:**

| Type | Behavior |
|------|----------|
| Arrays (`[[array-of-tables]]`) | Concatenate (base first, then overlay) |
| Tables (`[table]`) | Recursive deep merge (overlay wins on leaves) |
| Scalars | Overlay wins |

**Rules:**

- The `include` path is resolved relative to the overlay file's directory.
- Chained includes (an included file that itself has `include`) are not supported.
- The `include` key is consumed and does not appear in the merged config.

#### Config Source

Use `source` to point your local config at the authoritative copy in your dotfiles repository. Instead of syncing the config file back and forth, dotsync reads it directly from the repo, so changes take effect immediately — no pull needed.

```toml
# ~/.config/dotsync.toml (a thin pointer that never changes)
source = "$XDG_CONFIG_HOME_MIRROR/dotsync/dotsync.mbp_personal.toml"
```

```toml
# The real config in the repo (may itself use `include`)
include = "dotsync.base.toml"

[[sync.xdg_config]]
path = "nvim"
force = true
ignore = ["lazy-lock.json"]
```

**Rules:**

- `source` must be the **only** key in the pointer file.
- The source file may use `include` to compose with a base (resolved relative to the source file).
- Chained sources (a source file pointing at another source) are not supported.
- Environment variables are expanded in the `source` path.

This makes per-machine setup a one-liner: each machine's `~/.config/dotsync.toml` points at its own overlay in the repo.

```
dotfiles/xdg_config_home/dotsync/
  dotsync.base.toml            # shared mappings, hooks
  dotsync.mbp_personal.toml    # include + personal-only mappings
  dotsync.mbp_work.toml        # include + work-only mappings
  dotsync.mac_mini.toml        # include + mac-mini-only mappings
```

#### Environment Variables

- `DOTSYNC_CONFIG` — overrides the default config path (`~/.config/dotsync.toml`).
- `NO_COLOR` — disables ANSI color in output (color is also disabled automatically when stdout is not a TTY).
- Mirror variables such as `$HOME_MIRROR`, `$XDG_CONFIG_HOME_MIRROR`, etc. — referenced from your mappings and expanded at load time.
- `DOTSYNC_NO_TUI` — set to any value to disable the [interactive screen](#interactive-screen) everywhere, the same as passing `--no-tui`.
- `DOTSYNC_NO_CACHE` — accepted as a no-op for compatibility; the Go binary parses TOML directly and keeps no on-disk config cache.

### Safety Features

dotsync includes several mechanisms to prevent accidental data loss.

#### Invalid Paths and Auto-Create

A mapping is **invalid** when one of the following holds:

| Reason | Meaning | Fix hint shown |
|--------|---------|----------------|
| `source does not exist` | The source path is missing — a config error, or the repo has not been pulled yet | `check config or pull first` |
| `destination directory does not exist` | The destination directory does not exist locally yet (common when a mapping was added on another machine) | `--create-dest` |
| `source and destination are the same` | `src` and `dest` resolve to the same path | `check config` |
| `source and destination are nested` | One path is inside the other | `check config` |

Invalid mappings are reported in a dedicated **Invalid Paths** section that is **always shown** — even under `--quiet` — listing the source, destination, the specific reason, and the fix hint:

```
Invalid Paths (2):
  ~/dotfiles/.config/foo -> ~/.config/foo
    destination directory does not exist · fix: --create-dest
  ~/dotfiles/missing -> ~/elsewhere
    source does not exist · fix: check config or pull first
```

Invalid mappings are silently skipped during sync — but you never miss the report.

**Fixing missing destinations.** For `destination directory does not exist`, the destination (for a directory source) or its parent (for a file source) can be created automatically:

- **Flag mode** — create everything fixable, non-interactively:
  ```sh
  dotsync pull --create-dest --apply -y
  ```
- **Interactive mode** — prompt per-mapping during `--apply`:
  ```sh
  dotsync pull --apply
  # Missing destination directories:
  #   Create ~/.config/foo? [y/N/a/q] y
  #   Create ~/.local/share/bar? [y/N/a/q] a   # create all remaining
  ```
  Answers: `y` create this one, `n` skip, `a` create all remaining, `q` stop prompting.
- **Dry-run** — just lists what is invalid; no filesystem changes.

`watch` honours `--create-dest` at startup but never prompts.

#### Confirmation Prompts

Before applying changes, dotsync shows the differences, then asks for explicit confirmation:

```
About to modify 15 file(s).
Continue? [y/N] y
```

It only proceeds on `y`. Bypass the prompt with `-y/--yes` (or `-q/--quiet`, which also suppresses output). No prompt is shown when there are no differences.

#### Automatic Backups

When you run `pull --apply` and there are differences, dotsync first backs up the destination files it is about to overwrite:

- Backups are written under `$XDG_DATA_HOME/dotsync/backups/` (default `~/.local/share/dotsync/backups/`), in a timestamped directory `YYYYMMDDHHMMSS/`.
- Only the **10 most recent** backups are kept; older ones are purged.
- Backups are created only when there are actual differences.

To restore:

```sh
ls -la ~/.local/share/dotsync/backups/
cp -r ~/.local/share/dotsync/backups/20260814143022/* ~/.config/
```

#### Preview Mode (Dry-Run)

All `push` and `pull` commands run in preview mode by default: they show exactly what would change without modifying files. Pass `--apply` to make changes, or `--dry-run` for explicit clarity in scripts.

#### Error Handling

Transfer errors are reported per-mapping with an actionable hint, and processing continues with the remaining mappings:

- **Permission denied** — `Try: chmod +w <path> or check file permissions`
- **Disk full** — `Free up disk space and try again`
- **Symlink error** — `Check that symlink target exists and is accessible`
- **Type conflict** — `Cannot overwrite directory with file or vice versa`

#### Symlink Support

dotsync handles symbolic links correctly: it preserves symlink targets (absolute and relative), copies files atomically (temp file + rename) preserving the source's mode, and detects type conflicts (e.g. file vs. directory) with a clear error rather than clobbering.

### Customizing Icons

The status glyphs prefixing each mapping and diff line are overridable via an `[icons]` table in your config. The **defaults are plain ASCII** so output is legible on any terminal; override them with Nerd Font glyphs, emoji, or anything else — or set an icon to `""` to hide it.

```toml
[icons]
# Mapping status icons
force   = "!"    # source overwrites destination (force)
only    = ">"    # filtered by the 'only' whitelist
ignore  = "x"    # filtered by the 'ignore' blacklist
invalid = "?"    # invalid mapping
hook    = "@"    # post-sync hooks configured

# Diff status icons
diff_created = "+"   # created/added file
diff_updated = "~"   # updated/modified file
diff_removed = "-"   # removed/deleted file
```

| Key | Default | Purpose |
|-----|---------|---------|
| `force` | `!` | Force deletion enabled |
| `only` | `>` | `only` whitelist active |
| `ignore` | `x` | `ignore` blacklist active |
| `invalid` | `?` | Invalid mapping |
| `hook` | `@` | Post-sync hooks configured |
| `diff_created` | `+` | File created |
| `diff_updated` | `~` | File updated |
| `diff_removed` | `-` | File removed |

### Customizing Colors

Diff-line colors are 256-color palette indices, overridable via a `[colors]` table:

```toml
[colors]
diff_additions     = 34   # created/added files   (default 34)
diff_modifications = 36   # updated/modified files (default 36)
diff_removals      = 88   # removed/deleted files  (default 88)
```

Color is emitted only to a TTY, and is suppressed entirely when `NO_COLOR` is set or output is piped.

### Pro Tips

- **Preview before applying.** Always run without `--apply` first (`dotsync pull`, or `dotsync diff` for a quick push preview), review, then apply.
- **Inspect config with `status`.** `dotsync status` shows the resolved configuration and mappings without touching the filesystem.
- **Multiple config files.** Use `-c` to keep separate configs for work, personal, and per-machine setups:
  ```sh
  dotsync -c ~/work-dotfiles.toml push --apply
  dotsync --config ~/.config/personal.toml pull --apply
  ```
- **Unattended runs.** Combine `--apply`, `--yes`, `--create-dest`, and `--quiet` for CI or scripts:
  ```sh
  dotsync pull --apply --yes --create-dest --quiet
  ```
- **Quiet vs. verbose.** Output is quiet by default (differences + invalid paths). Opt into detail:
  ```sh
  dotsync pull -v                # everything (options, env vars, legends, mappings)
  dotsync pull --show-mappings   # quiet + mappings table
  dotsync pull --legend          # quiet + legends only
  ```

## Common Use Cases

### Neovim

```toml
[[sync.xdg_config]]
path = "nvim"
force = true
ignore = ["lazy-lock.json", ".luarc.json"]
```

### Terminal emulator (Alacritty)

```toml
[[sync.xdg_config]]
path = "alacritty"
only = ["alacritty.toml", "themes"]
```

### Shell configuration

```toml
[[sync.home]]
path = ".zshenv"

[[sync.xdg_config]]
path = "zsh"
ignore = [".zsh_sessions", ".zsh_history", ".zcompdump"]
```

### Many directories at once

```toml
[[sync.xdg_config]]
only = ["nvim", "alacritty", "git", "zsh", "tmux", "starship.toml"]
force = true
```

### Per-machine configuration

Use `include` to share a base config across machines, with each machine adding only its delta (see [Config Includes](#config-includes) and [Config Source](#config-source)). Select a config explicitly with `-c`:

```sh
dotsync -c ~/.config/dotsync/dotsync.macbook.toml push --apply
```

## Troubleshooting

### Icons appear as boxes or question marks

The default icons are ASCII, so this is unusual — but if you have overridden them with Nerd Font glyphs, install a [Nerd Font](https://www.nerdfonts.com/) and configure your terminal to use it, or set plain-ASCII/emoji values in the `[icons]` table (see [Customizing Icons](#customizing-icons)).

### Changes are not being applied

`push`/`pull` run in preview mode by default. Add `--apply`:

```sh
dotsync pull --apply
dotsync push --apply
```

### Permission denied errors

Ensure you have write permission for the destination directories (`ls -la ~/.config`), and map to user-writable locations rather than system directories.

### Source or destination not found

Mappings reported under **Invalid Paths**:

- `destination directory does not exist`: re-run with `--create-dest`, or run `--apply` (without `-y`) to be prompted per mapping.
- `source does not exist`: check that your mirror environment variables are set (e.g. `echo $XDG_CONFIG_HOME_MIRROR`), or pull the dotfiles repo first so the source path exists.

### Restoring from a backup

`pull --apply` writes backups under `~/.local/share/dotsync/backups/`:

```sh
ls -la ~/.local/share/dotsync/backups/
cp -r ~/.local/share/dotsync/backups/YYYYMMDDHHMMSS/* ~/.config/
```

### The confirmation prompt appears in scripts

Use `-y/--yes` to skip it (and pair with `--create-dest` if you want missing destinations created):

```sh
dotsync push --apply --yes
dotsync pull --apply --yes --create-dest --quiet
```

### Config file not found

Create one with `dotsync setup` (writes `~/.config/dotsync.toml`), or point at an existing file with `-c`:

```sh
dotsync setup
dotsync -c ~/my-config.toml push
```

## Development

```sh
go build ./cmd/dotsync      # build the binary
go test ./...               # run the test suite
go vet ./...                # static checks
gofmt -l .                  # must print nothing (all files formatted)
```

CI (GitHub Actions) runs `gofmt`, `go vet`, `go test`, and `go build` on Linux and macOS. Parity-affecting changes are additionally checked by a differential harness that runs the Ruby oracle and the Go binary against a shared fixture corpus and diffs filesystem state, exit codes, and output.

Contributor guidance lives in [`AGENTS.md`](AGENTS.md); architecture decisions and how-it-works explainers live under [`docs/architecture/`](docs/architecture).

## Architecture

dotsync is layered so the **engine computes data and renders nothing** — the diff engine returns data structures that each consumer (the classic line renderer, and, later, the TUI and the test harness) renders independently.

```
              +-----------+     +--------+     +----------+
  config ---> |  model    | --> | engine | --> |  render  | --> stdout
  (TOML)      | (Mapping) |     | (Diff) |     | (classic |
              +-----------+     +--------+     |  line)   |
                                   |           +----------+
                                   v
                              transfer (apply)
```

See [`AGENTS.md`](AGENTS.md#architecture) for the package map and [`docs/architecture/`](docs/architecture) for the decision records and explainers.

## Contributing

Bug reports and pull requests are welcome at <https://github.com/dsaenztagarro/dotsync>. Please run the full gate (`gofmt -l .`, `go vet ./...`, `go test ./...`) before opening a PR; see [`AGENTS.md`](AGENTS.md) for the workflow.

## License

MIT © David Sáenz — see [LICENSE](LICENSE).
