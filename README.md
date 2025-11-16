# Dotsync

[![Gem Version](https://badge.fury.io/rb/dotsync.svg)](https://rubygems.org/gems/dotsync)
[![CI](https://github.com/dsaenztagarro/dotsync/actions/workflows/gem-push.yml/badge.svg)](https://github.com/dsaenztagarro/dotsync/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%203.2-blue)](https://www.ruby-lang.org/)

> [!WARNING]
> This gem is under active development. You can expect new changes that may not be backward-compatible.

## What is Dotsync?

Dotsync is a powerful Ruby gem for managing and synchronizing your dotfiles across machines. Whether you're setting up a new development environment or keeping configurations in sync, Dotsync makes it effortless.

**Key Features:**
- **Bidirectional Sync**: Push local dotfiles to your repository or pull from repository to local machine
- **Preview Mode**: See what changes would be made before applying them (dry-run by default)
- **Smart Filtering**: Use `force`, `only`, and `ignore` options to precisely control what gets synced
- **Automatic Backups**: Pull operations create timestamped backups for easy recovery
- **Live Watching**: Continuously monitor and sync changes in real-time with `watch` command
- **Customizable Output**: Control verbosity and customize icons to match your preferences
- **Auto-Updates**: Get notified when new versions are available

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Executable Commands](#executable-commands)
  - [Configuration](#configuration)
  - [Safety Features](#safety-features)
  - [Customizing Icons](#customizing-icons)
  - [Automatic Update Checks](#automatic-update-checks)
  - [Pro Tips](#pro-tips)
- [Common Use Cases](#common-use-cases)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)
- [Code of Conduct](#code-of-conduct)

  ![dotsync options](docs/images/dotsync_options.png)

## Requirements
- Ruby: MRI 3.2+

## Installation

Add this line to your application's Gemfile:

```ruby
gem "dotsync"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install dotsync

## Quick Start

Get started with Dotsync in just a few steps:

1. **Install the gem**:
   ```shell
   gem install dotsync
   ```

2. **Generate a default configuration**:
   ```shell
   dotsync setup
   ```
   This creates `~/.config/dotsync.toml` with example mappings.

3. **Edit the configuration** (`~/.config/dotsync.toml`) to define your dotfile mappings:
   ```toml
   [[pull.mappings]]
   src = "$HOME/dotfiles/config"
   dest = "$HOME/.config"
   ```

4. **Preview your changes** (dry-run mode):
   ```shell
   dotsync pull
   ```
   This shows what would be changed without modifying any files.

5. **Apply changes** when you're ready:
   ```shell
   dotsync pull --apply
   ```

## Usage

### Executable Commands

Dotsync provides the following commands to manage your dotfiles:

> [!IMPORTANT]
> By default, both `push` and `pull` commands run in **preview mode** (dry-run). They will show you what changes would be made without actually modifying any files. To apply changes, you **must** use the `--apply` flag.

#### Core Commands

- **Push**: Transfer dotfiles from your local machine to the destination repository.
  ```shell
  dotsync push [OPTIONS]
  dotsync push --apply [OPTIONS]  # Apply changes
  ```

  ![dotsync push](docs/images/dotsync_push.png)

- **Pull**: Synchronize dotfiles from the repository to your local machine.
  ```shell
  dotsync pull [OPTIONS]
  dotsync pull --apply [OPTIONS]  # Apply changes
  ```

  During the `pull` operation, `Dotsync::PullAction` creates a backup of the existing files on the destination. These backups are stored in a directory under the XDG path, with each backup organized by a timestamp. To prevent excessive storage usage, only the 10 most recent backups are retained. Older backups are automatically purged, ensuring efficient storage management.

  ![dotsync pull](docs/images/dotsync_pull.png)

- **Watch**: Continuously monitor and sync changes between your local machine and the repository.
  ```shell
  dotsync watch [OPTIONS]
  ```
  
  The watch command supports the same output control options as push and pull (e.g., `--quiet`, `--no-legend`, `--no-mappings`).

- **Setup** (alias: **init**): Generate a default configuration file at `~/.config/dotsync.toml` with example mappings for `pull`, `push`, and `watch`.
  ```shell
  dotsync setup
  dotsync init     # Alias for setup
  ```

#### Utility Commands

- **Status**: Display current configuration and mappings without executing any actions.
  ```shell
  dotsync status
  ```
  This is useful for inspecting your configuration and verifying mappings are correct.

- **Diff**: Show differences that would be made (alias for `push` in preview mode).
  ```shell
  dotsync diff
  ```
  Convenient shorthand for previewing changes without typing `--dry-run`.

#### Command Options

All push and pull commands support the following options:

**Action Control:**
- `-a, --apply`: Apply changes (without this, commands run in preview mode)
- `--dry-run`: Explicitly run in preview mode without applying changes (default behavior)
- `-y, --yes`: Skip confirmation prompt and auto-confirm changes
- `-c, --config PATH`: Specify a custom config file path (enables multiple config workflows)

**Output Control:**
- `-q, --quiet`: Hide all non-essential output (only errors or final status)
- `--no-legend`: Hide all legends for config, mappings, and differences
- `--no-config`: Hide the config section in the output
- `--no-mappings`: Hide the mappings and their legend
- `--no-diff-legend`: Hide the differences legend only
- `--no-diff`: Hide the differences section itself
- `--only-diff`: Show only the differences section
- `--only-config`: Show only the config section
- `--only-mappings`: Show only the mappings section
- `-v, --verbose`: Force showing all available information

**General:**
- `--version`: Display version number
- `-h, --help`: Show help message

#### Examples

```shell
# Setup and configuration
dotsync setup                      # Create initial config file
dotsync init                       # Same as setup (alias)
dotsync status                     # View current configuration

# Preview changes (dry-run mode)
dotsync push                       # Preview push changes
dotsync pull                       # Preview pull changes
dotsync diff                       # Quick preview (alias for push)
dotsync push --dry-run             # Explicit dry-run flag

# Apply changes
dotsync push --apply               # Apply changes with confirmation
dotsync pull --apply               # Apply changes with confirmation
dotsync push -ay                   # Apply without confirmation (--apply + --yes)
dotsync pull --apply --yes         # Apply without confirmation

# Custom configuration files
dotsync -c ~/work-dotfiles.toml push      # Use work config
dotsync --config ~/.config/personal.toml pull  # Use personal config

# Output control
dotsync pull --quiet               # Minimal output
dotsync push --only-diff           # Show only differences
dotsync pull --apply --yes -q      # Silent apply for scripts

# Monitoring
dotsync watch                      # Watch with default output
dotsync watch --quiet              # Watch with minimal output
```

### Configuration

The configuration file uses a `mappings` structure to define the source and destination of your dotfiles. Here is an example:

```toml
[[pull.mappings]]
src = "$XDG_CONFIG_HOME_MIRROR"
dest = "$XDG_CONFIG_HOME"
ignore = ["nvim"]

[[pull.mappings]]
src  = "$XDG_CONFIG_HOME_MIRROR/nvim"
dest = "$XDG_CONFIG_HOME/nvim"
# FEATURE: forces the deletion of destination folder
force = true
# FEATURE: use relative paths to "dest" to ignore files and folders
ignore = ["lazy-lock.json"]

[[pull.mappings]]
src = "$HOME_MIRROR/.zshenv"
dest = "$HOME"


[[push.mappings]]
src = "$HOME/.zshenv"
dest = "$HOME_MIRROR/.zshenv"

[[push.mappings]]
src = "$XDG_CONFIG_HOME/alacritty"
dest = "$DOTFILES_DIR/config/alacritty"
# FEATURE: transfer only relative paths of files and folders passed here
only = ["alacritty.toml", "rose-pine.toml"]


[[watch.mappings]]
src = "$HOME/.zshenv"
dest = "$HOME_MIRROR/.zshenv"

[[watch.mappings]]
src = "$XDG_CONFIG_HOME/alacritty"
dest = "$DOTFILES_DIR/config/alacritty"
```

> [!TIP]
> I use mirror environment variables to cleaner configuration
>
>  ```bash
>  export XDG_CONFIG_HOME_MIRROR="$HOME/Code/dotfiles/xdg_config_home"
>  ```

#### `force`, `only`, and `ignore` Options in Mappings

Each mapping entry supports the following options:

##### `force` Option

A boolean (true/false) value. When set to `true`, it forces deletion of files in the destination directory that don't exist in the source. This is particularly useful when you need to ensure the destination stays synchronized with the source.

**Example:**
```toml
[[pull.mappings]]
src = "$XDG_CONFIG_HOME_MIRROR/nvim"
dest = "$XDG_CONFIG_HOME/nvim"
force = true
ignore = ["lazy-lock.json"]
```

> [!WARNING]
> When using `force = true` with the `only` option, only files matching the `only` filter will be managed. Other files in the destination remain untouched.

##### `only` Option

An array of relative paths (files or directories) to selectively transfer from the source. This option provides precise control over which files get synchronized.

**How it works:**
- Paths are relative to the `src` directory
- You can specify entire directories or individual files
- Parent directories are automatically created as needed
- Other files in the source are ignored
- With `force = true`, only files matching the `only` filter are cleaned up in the destination

**Example 1: Selecting specific directories**
```toml
[[push.mappings]]
src = "$XDG_CONFIG_HOME"
dest = "$DOTFILES_DIR/config"
only = ["nvim", "alacritty", "zsh"]
```
This transfers only the `nvim/`, `alacritty/`, and `zsh/` directories.

**Example 2: Selecting specific files**
```toml
[[push.mappings]]
src = "$XDG_CONFIG_HOME/alacritty"
dest = "$DOTFILES_DIR/config/alacritty"
only = ["alacritty.toml", "rose-pine.toml"]
```
This transfers only two specific TOML files from the alacritty config directory.

**Example 3: Selecting files inside nested directories**
```toml
[[push.mappings]]
src = "$HOME/.config"
dest = "$DOTFILES_DIR/config"
only = ["bundle/config", "ghc/ghci.conf", "cabal/config"]
```
This transfers only specific configuration files from different subdirectories:
- `bundle/config` file from the `bundle/` directory
- `ghc/ghci.conf` file from the `ghc/` directory  
- `cabal/config` file from the `cabal/` directory

The parent directories (`bundle/`, `ghc/`, `cabal/`) are created automatically in the destination, but other files in those directories are not transferred.

**Example 4: Deeply nested paths**
```toml
[[push.mappings]]
src = "$XDG_CONFIG_HOME"
dest = "$DOTFILES_DIR/config"
only = ["nvim/lua/plugins/init.lua", "nvim/lua/config/settings.lua"]
```
This transfers only specific Lua files from deeply nested paths within the nvim configuration.

**Important behaviors:**
- **File-specific paths**: When specifying individual files (e.g., `"bundle/config"`), only that file is managed. Sibling files in the same directory are not affected, even with `force = true`.
- **Directory paths**: When specifying directories (e.g., `"nvim"`), all contents of that directory are managed, including subdirectories.
- **Combining with `force`**: With `force = true` and directory paths, files in the destination directory that don't exist in the source are removed. With file-specific paths, only that specific file is managed.

##### `ignore` Option

An array of relative paths or patterns to exclude during transfer. This allows you to skip certain files or folders.

**Example:**
```toml
[[pull.mappings]]
src = "$XDG_CONFIG_HOME_MIRROR/nvim"
dest = "$XDG_CONFIG_HOME/nvim"
ignore = ["lazy-lock.json", "plugin/packer_compiled.lua"]
```

**Combining options:**
```toml
[[push.mappings]]
src = "$XDG_CONFIG_HOME/nvim"
dest = "$DOTFILES_DIR/config/nvim"
only = ["lua", "init.lua"]
ignore = ["lua/plugin/packer_compiled.lua"]
force = true
```
This configuration:
1. Transfers only the `lua/` directory and `init.lua` file (`only`)
2. Excludes `lua/plugin/packer_compiled.lua` even though it's in the `lua/` directory (`ignore`)
3. Removes files in the destination that don't exist in the source (`force`)

> [!NOTE]
> When `ignore` and `only` both match a path, `ignore` takes precedence.

These options apply when the source is a directory and are relevant for both `push` and `pull` operations.

### Safety Features

Dotsync includes several safety mechanisms to prevent accidental data loss:

#### Confirmation Prompts

Before applying any changes with the `--apply` flag, Dotsync will:
1. Show you all differences that will be applied
2. Display the total count of files to be modified
3. Ask for explicit confirmation: `About to modify X file(s). Continue? [y/N]`
4. Only proceed if you type `y` and press Enter

**Example:**
```shell
$ dotsync push --apply

# ... shows differences ...

About to modify 15 file(s).
Continue? [y/N] y
```

**Bypassing Confirmation:**
- Use the `--yes` or `-y` flag to skip confirmation (useful for automation):
  ```shell
  dotsync push --apply --yes
  dotsync pull -ay              # Short form
  ```
- Use the `--quiet` flag (automatically skips prompt and suppresses output)

> [!NOTE]
> No confirmation is shown if there are no differences to apply.

#### Automatic Backups

When using `pull --apply`, Dotsync automatically:
- Creates timestamped backups of existing files before overwriting them
- Stores backups in `~/.cache/dotsync/backups/YYYYMMDDHHMMSS/`
- Retains only the 10 most recent backups (older ones are purged)
- Creates backups only when there are actual differences

To restore from a backup:
```shell
ls -la ~/.cache/dotsync/backups/
cp -r ~/.cache/dotsync/backups/20250110143022/* ~/.config/
```

#### Preview Mode (Dry-Run)

By default, all `push` and `pull` commands run in preview mode:
- Shows exactly what would change without modifying files
- Must explicitly use `--apply` flag to make changes
- Use `--dry-run` flag for explicit clarity in scripts

#### Enhanced Error Handling

Dotsync provides clear, actionable error messages for common issues:

- **Permission Errors**: 
  ```
  Permission denied: /path/to/file
  Try: chmod +w <path> or check file permissions
  ```

- **Disk Full Errors**:
  ```
  Disk full: No space left on device
  Free up disk space and try again
  ```

- **Symlink Errors**:
  ```
  Symlink error: Target does not exist
  Check that symlink target exists and is accessible
  ```

- **Type Conflicts**:
  ```
  Type conflict: Cannot overwrite directory with file
  Cannot overwrite directory with file or vice versa
  ```

Errors are reported per-mapping, allowing Dotsync to continue processing other mappings even if one fails.

#### Symlink Support

Dotsync properly handles symbolic links:
- Preserves symlink targets (absolute and relative paths)
- Handles broken symlinks gracefully
- Detects type conflicts (e.g., file vs. directory vs. symlink)
- Provides clear error messages for symlink-related issues

### Customizing Icons

Dotsync allows you to customize the icons displayed in the console output by adding an `[icons]` section to your configuration file (`~/.config/dotsync.toml`). This is useful if you prefer different icons or need compatibility with terminals that don't support Nerd Fonts.

#### Available Icon Options

You can customize the following icons in your configuration:

**Mapping Status Icons** (shown next to each mapping):
- `force` - Indicates force deletion is enabled (clears destination before transfer)
- `only` - Indicates only specific files will be transferred
- `ignore` - Indicates files are being ignored during transfer
- `invalid` - Indicates the mapping is invalid (missing source/destination)

**Difference Status Icons** (shown in diff output):
- `diff_created` - Shows newly created/added files
- `diff_updated` - Shows updated/modified files
- `diff_removed` - Shows removed/deleted files

#### Example Configuration

Here's a complete example showing all customizable icons using UTF-8 emojis (works without Nerd Fonts):

```toml
[icons]
# Mapping status icons
force = "⚡"           # Force deletion enabled
only = "📋"            # Only specific files transferred
ignore = "🚫"          # Files ignored during transfer
invalid = "❌"         # Invalid mapping

# Diff status icons
diff_created = "✨"    # New files created
diff_updated = "📝"    # Files modified
diff_removed = "🗑️ "    # Files deleted

# Example mappings section
[[pull.mappings]]
src = "$XDG_CONFIG_HOME_MIRROR"
dest = "$XDG_CONFIG_HOME"
ignore = ["cache"]
```

#### Default Icons

If you don't specify custom icons, Dotsync uses [Nerd Font](https://www.nerdfonts.com) icons by default. These icons will only display correctly if you're using a terminal with a patched Nerd Font installed.

| Icon | Default (Nerd Font) | Nerd Font Code | Purpose |
|------|---------------------|----------------|---------|
| `force` | `󰁪 ` | `nf-md-lightning_bolt` | Force deletion enabled |
| `only` | ` ` | `nf-md-filter` | Only mode active |
| `ignore` | `󰈉 ` | `nf-md-cancel` | Ignoring files |
| `invalid` | `󱏏 ` | `nf-md-alert_octagram` | Invalid mapping |
| `diff_created` | ` ` | `nf-md-plus` | File created |
| `diff_updated` | ` ` | `nf-md-pencil` | File updated |
| `diff_removed` | ` ` | `nf-md-minus` | File removed |

> [!NOTE]
> The icons in the "Default (Nerd Font)" column may not be visible unless you're viewing this with a Nerd Font. You can find these icons at [nerdfonts.com](https://www.nerdfonts.com/cheat-sheet) by searching for the Nerd Font Code.

> [!TIP]
> You can set any icon to an empty string (`""`) to hide it completely, or use any UTF-8 character or emoji. The `dotsync setup` command generates a configuration file with some example custom icons to get you started.

### Automatic Update Checks

Dotsync automatically checks for new versions once per day and notifies you if an update is available. This check is non-intrusive and will not interrupt your workflow.

To disable automatic update checks:
- Set environment variable: `export DOTSYNC_NO_UPDATE_CHECK=1`

The check runs after your command completes and uses a cached timestamp to avoid excessive API calls. The cache is stored in `~/.cache/dotsync/last_version_check` following the XDG Base Directory specification.

### Pro Tips

- **Preview Before Applying**: Always run commands without `--apply` first to preview changes:
  ```shell
  dotsync pull          # Preview changes
  dotsync diff          # Quick preview (alias)
  dotsync pull --apply  # Apply after reviewing
  ```

- **Check Configuration**: Use the `status` command to inspect your configuration without executing any actions:
  ```shell
  dotsync status        # View config and mappings
  ```

- **Multiple Config Files**: Use the `-c` flag to maintain separate configurations for different workflows:
  ```bash
  # Work dotfiles
  dotsync -c ~/work-dotfiles.toml push --apply
  
  # Personal dotfiles
  dotsync -c ~/.config/personal.toml pull --apply
  
  # Server configs
  dotsync --config ~/server.toml push --apply
  ```

- **Automation and Scripting**: Use `--yes` flag to skip confirmation prompts:
  ```shell
  # In a script or CI/CD pipeline
  dotsync pull --apply --yes --quiet
  
  # Shorthand
  dotsync push -ayq
  ```

- **Using Environment Variables**: Simplify your configuration with mirror environment variables:
  ```bash
  # Add to your ~/.zshrc or ~/.bashrc
  export DOTFILES_DIR="$HOME/dotfiles"
  export XDG_CONFIG_HOME_MIRROR="$DOTFILES_DIR/config"
  export HOME_MIRROR="$DOTFILES_DIR/home"
  ```

- **Backup Location**: Pull operations automatically backup files to `~/.cache/dotsync/backups/` with timestamps. Only the 10 most recent backups are kept.

- **Using rbenv**: To ensure the gem uses the correct Ruby version managed by rbenv:
  ```shell
  RBENV_VERSION=3.2.0 dotsync push
  ```

- **Global Installation**: Install the gem using a globally available Ruby version to make the executable accessible anywhere:
  ```shell
  gem install dotsync
  ```

- **Check Version**: Quickly check which version you're running:
  ```shell
  dotsync --version
  ```

- **Disable Update Checks**: If you prefer not to see update notifications:
  ```shell
  export DOTSYNC_NO_UPDATE_CHECK=1
  ```

- **Quiet Mode**: For use in scripts or when you only want to see errors:
  ```shell
  dotsync pull --apply --quiet
  ```

## Common Use Cases

Here are some practical examples of how to use Dotsync for popular configuration files:

### Syncing Neovim Configuration

```toml
[[pull.mappings]]
src = "$HOME/dotfiles/config/nvim"
dest = "$HOME/.config/nvim"
force = true
ignore = ["lazy-lock.json", ".luarc.json"]
```

### Syncing Terminal Emulator (Alacritty)

```toml
[[push.mappings]]
src = "$HOME/.config/alacritty"
dest = "$HOME/dotfiles/config/alacritty"
only = ["alacritty.toml", "themes"]
```

### Syncing Shell Configuration

```toml
[[pull.mappings]]
src = "$HOME/dotfiles/shell/.zshrc"
dest = "$HOME"

[[pull.mappings]]
src = "$HOME/dotfiles/shell/.zshenv"
dest = "$HOME"
```

### Syncing Multiple Config Directories

```toml
[[pull.mappings]]
src = "$HOME/dotfiles/config"
dest = "$HOME/.config"
ignore = ["nvim", "cache", "*.log"]
```

## Troubleshooting

### Icons Not Displaying Correctly

**Problem**: Icons appear as boxes, question marks, or strange characters.

**Solution**: 
- Install a [Nerd Font](https://www.nerdfonts.com/) and configure your terminal to use it
- Or customize icons in `~/.config/dotsync.toml` using UTF-8 emojis or regular characters:
  ```toml
  [icons]
  force = "!"
  only = "*"
  ignore = "x"
  invalid = "?"
  diff_created = "+"
  diff_updated = "~"
  diff_removed = "-"
  ```

### Changes Not Being Applied

**Problem**: Running `dotsync push` or `dotsync pull` doesn't modify files.

**Solution**: Remember to use the `--apply` flag to apply changes. Without it, commands run in preview mode:
```shell
dotsync pull --apply
dotsync push --apply
```

You can also use the explicit `--dry-run` flag to make preview mode clear in scripts.

### Permission Denied Errors

**Problem**: Getting permission errors when syncing files.

**Solution**:
- Ensure you have write permissions for destination directories
- Check file ownership: `ls -la ~/.config`
- For system directories, you may need to adjust your mappings to use user-writable locations

### Source or Destination Not Found

**Problem**: Error messages about missing source or destination paths.

**Solution**:
- Verify environment variables are set correctly (e.g., `echo $XDG_CONFIG_HOME`)
- Use absolute paths in your configuration if environment variables aren't available
- Create destination directories before running pull: `mkdir -p ~/.config`

### Restoring from Backups

**Problem**: Need to restore files after a pull operation.

**Solution**: Pull operations create automatic backups in `~/.cache/dotsync/backups/`:
```shell
ls -la ~/.cache/dotsync/backups/
# Copy files from the timestamped backup directory
cp -r ~/.cache/dotsync/backups/YYYYMMDD_HHMMSS/* ~/.config/
```

### Watch Command Not Detecting Changes

**Problem**: `dotsync watch` doesn't sync changes automatically.

**Solution**:
- Verify your watch mappings are configured correctly in `~/.config/dotsync.toml`
- Ensure the source directories exist and are accessible
- Try stopping and restarting the watch command

### Confirmation Prompt Appearing

**Problem**: Being prompted to confirm changes when running in scripts or automation.

**Solution**: Use the `--yes` or `-y` flag to skip confirmation prompts:
```shell
dotsync push --apply --yes
dotsync pull -ay              # Shorthand
```

For completely silent operation in scripts:
```shell
dotsync push --apply --yes --quiet
```

### Using Multiple Config Files

**Problem**: Need different dotfile configurations for work, personal, or different machines.

**Solution**: Use the `--config` or `-c` flag to specify custom config files:
```shell
dotsync -c ~/work-dotfiles.toml push
dotsync --config ~/.config/personal.toml pull
```

You can maintain separate config files for different environments and switch between them easily.

### Config File Not Found

**Problem**: Error message about missing config file.

**Solution**: Create a config file using the setup command:
```shell
dotsync setup    # Creates ~/.config/dotsync.toml
dotsync init     # Alias for setup
```

Or specify a custom config file path:
```shell
dotsync -c ~/my-config.toml setup
```

## Development

- After checking out the repo, run `bin/setup` to install dependencies.
- Then, run `rake spec` to run the tests.
- You can also run `bin/console` for an interactive prompt that will allow you to experiment.
- To install this gem onto your local machine, run `bundle exec rake install`.

### Releasing a new version
- Update the version number in `version.rb`.
- Run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dsaenztagarro/dotsync. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Dotsync project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/dsaenztagarro/dotsync/blob/master/CODE_OF_CONDUCT.md).
