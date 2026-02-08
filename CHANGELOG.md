## [0.2.2] - 2026-02-08

**New Features:**
- Add per-mapping post-sync hooks that run commands after files are transferred
  - `post_sync` — runs after sync in both directions (`[[sync]]` mappings)
  - `post_push` — runs only after push (`[[sync]]` and `[[push]]` mappings)
  - `post_pull` — runs only after pull (`[[sync]]` and `[[pull]]` mappings)
  - Template variables: `{files}` (shell-quoted changed dest paths), `{src}`, `{dest}`
  - Hooks only execute when files actually changed and only with `--apply`
  - Hook failures log errors but do not abort remaining hooks or mappings
  - Preview mode shows what commands would run without executing
- Add `HookError` error class for hook-related errors
- Add hook icon (󰜎) to mappings legend with custom icon support
- Add glob pattern support to `only` filter (#15)
  - `*` matches any sequence of characters (e.g., `local.*.plist`)
  - `?` matches any single character (e.g., `config.?`)
  - `[charset]` matches any character in the set (e.g., `log.[0-9]`)
  - Glob and exact paths can be mixed in the same `only` array
  - Non-glob entries retain existing exact path matching behavior

**New Files:**
- `lib/dotsync/utils/hook_runner.rb` — HookRunner utility with execute, preview, and template expansion
- `spec/dotsync/utils/hook_runner_spec.rb` — Comprehensive tests for HookRunner

**Documentation:**
- Add "Post-Sync Hooks" section to README with hook types, examples, template variables, and real-world use cases
- Add post-sync hooks to Key Features and Table of Contents
- Document glob pattern support in README with examples
- Add "Glob patterns" to the `only` option important behaviors section

**Testing:**
- Add 35 new test examples covering hooks across all layers
  - HookRunner: template expansion, multiple commands, failure handling, shell-escaped paths, preview mode
  - Mapping: hooks attribute, has_hooks?, hook icon display
  - SyncMappings: direction resolution, array concatenation, shorthand hooks, validation of invalid keys
  - PushActionConfig/PullActionConfig: hook extraction, validation of unidirectional constraints
  - PushAction/PullAction: hook execution with changes, skipped without changes, skipped in dry-run
- Add unit tests for glob matching in `include?`, `bidirectional_include?`, `skip?`, `should_prune_directory?`
- Add integration tests for glob patterns in FileTransfer (including force mode)
- Add integration tests for glob patterns in DirectoryDiffer
## [0.2.1] - 2025-02-06

**Performance Optimizations:**
- Add pre-indexed source tree for O(1) existence checks during force mode
  - Builds a Set of source paths upfront instead of per-file File.exist? calls
  - Replaces disk I/O with memory lookups for removal detection
  - Significant speedup for large destination directories
- Combined performance impact: `ds pull` reduced from 7.2s to 0.6s (12x faster)
  - Pre-indexed source tree eliminates thousands of stat calls
  - Find.prune skips irrelevant directory subtrees
  - Parallel execution overlaps I/O across mappings

**Documentation:**
- Add comprehensive performance documentation to DirectoryDiffer
  - Document all three optimizations with impact analysis
  - Inline comments explaining each optimization point
- Add class-level documentation to Mapping explaining path matching methods
  - Document relationship between include?, bidirectional_include?, should_prune_directory?
- Add module documentation to Parallel explaining when parallelization helps
- Add documentation to MappingsTransfer explaining parallel strategy

**Infrastructure:**
- Remove RubyGems auto-publish from CI workflow (manual releases only)

## [0.2.0] - 2025-02-06

**New Features:**
- Add `--diff-content` CLI option to display git-like unified diff output for modified files
  - Shows actual content changes without needing external tools like `nvim -d`
  - Color-coded output: blue for additions, red for deletions, cyan for hunk headers
  - Automatically skips binary files
  - Works with both `push` and `pull` commands

**Performance Optimizations:**
- Add parallel processing for mapping operations
  - New `Dotsync::Parallel` utility module with thread-pool based execution
  - Diff computation runs in parallel across multiple mappings
  - File transfers execute concurrently for independent mappings
  - Thread-safe error collection and reporting
- Add directory pruning optimization
  - New `should_prune_directory?` method for early-exit during traversal
  - Skips entire directory subtrees that are ignored or outside inclusion lists
  - Reduces filesystem operations for large excluded directories

## [0.1.26] - 2025-01-11

**Breaking Changes:**
- The explicit sync mapping syntax has changed from `[[sync]]` to `[[sync.mappings]]`
  - Old: `[[sync]]` with `local`/`remote` keys
  - New: `[[sync.mappings]]` with `local`/`remote` keys
  - This allows combining explicit mappings with XDG shorthands in the same config
  - See README for migration examples

**New Features:**
- Add bidirectional `[[sync.mappings]]` DSL for two-way synchronization
  - Simplified syntax replaces separate push/pull mappings
  - Automatic expansion to bidirectional mappings (local ↔ remote)
  - Supports all existing options: `force`, `only`, `ignore`
- Add XDG shorthand DSL for sync mappings
  - `[[sync.home]]` - syncs $HOME ↔ $HOME_MIRROR
  - `[[sync.xdg_config]]` - syncs $XDG_CONFIG_HOME ↔ $XDG_CONFIG_HOME_MIRROR
  - `[[sync.xdg_data]]` - syncs $XDG_DATA_HOME ↔ $XDG_DATA_HOME_MIRROR
  - `[[sync.xdg_cache]]` - syncs $XDG_CACHE_HOME ↔ $XDG_CACHE_HOME_MIRROR
  - `[[sync.xdg_bin]]` - syncs $XDG_BIN_HOME ↔ $XDG_BIN_HOME_MIRROR (new)
  - Use `path` for specific subdirectories or `only` for multiple paths
- Fix custom config path (`-c` flag) not being applied to Runner

**Documentation:**
- Document bidirectional sync mappings with examples
- Document XDG shorthand DSL with usage examples
- Update README with new configuration options and supported shorthands table

**Infrastructure:**
- Rename GitHub workflow to ci.yml
- Add sync_mappings concern to push and pull loaders

## [0.1.25]

**Features:**
- Add support for file-specific paths in 'only' configuration option
  - Enable specifying individual files within directories: `only = ["bundle/config", "ghc/ghci.conf"]`
  - Parent directories are automatically created as needed
  - Sibling files in the same directory remain unaffected
  - Works with deeply nested paths: `only = ["nvim/lua/plugins/init.lua"]`
  - Fix DirectoryDiffer to use bidirectional_include? for proper file traversal

**Documentation:**
- Completely rewrite 'force', 'only', and 'ignore' options section in README
- Add 4 detailed examples showing different use cases
- Add warnings and notes about combining options
- Document important behaviors and edge cases

**Testing:**
- Add comprehensive test coverage for file-specific paths in 'only' option
- Add tests for FileTransfer with nested file paths
- Add tests for DirectoryDiffer with file-specific only paths
- Add tests with force mode enabled
- All 396 tests pass with 96.61% line coverage

# 0.1.24

**Performance Optimizations:**
- Implement lazy loading to defer library loading until after argument parsing
  - Reduces `--version` and `--help` startup time from ~900ms to ~380ms (2.4x faster)
  - Full library only loaded when executing actual commands
- Add action-specific loaders to reduce memory footprint
  - Each command loads only its required dependencies
  - Push/pull skip loading 'listen' gem (only needed for watch)
  - Watch skips terminal-table and diff logic
  - Setup uses minimal dependencies for near-instant execution
- Add config caching with XDG_DATA_HOME integration
  - Caches parsed TOML as Marshal binary (~180x faster to load)
  - Automatic cache invalidation based on mtime, size, and version
  - Graceful fallback to TOML parsing on errors
  - Disable with `DOTSYNC_NO_CACHE=1` environment variable
  - Saves ~14ms per invocation on typical configs

**Combined Performance Impact:**
- `--version`: 900ms → 380ms (2.4x faster)
- `--help`: 900ms → 380ms (2.4x faster)
- Setup: Near-instant with minimal loading
- Push/pull: ~15% faster with cached config
- Watch: ~40% faster without unnecessary dependencies

# 0.1.23

**Critical Bug Fix:**
- Fix cleanup_folder to respect 'only' filter and prevent unintended deletions
  - When force=true was used with an 'only' filter, cleanup_folder was deleting all files in the destination that weren't explicitly ignored, including unrelated folders not being managed by the mapping
  - This caused data loss for folders like cabal/ and ghc/ that weren't in the only list
  - The fix ensures only paths matching the inclusion filter are cleaned up, leaving unmanaged content intact

**Test Coverage:**
- Add comprehensive test coverage for the cleanup_folder bug fix
- Test preserving unrelated folders when using force + only
- Test only cleaning managed paths specified in only list
- Test edge case with empty source and unmanaged dest content
- Update existing test to reflect correct behavior
- Total: 326 examples, 0 failures, 2 pending with 96.41% line coverage

# 0.1.22

**Testing & Quality:**
- Increase test coverage from 89.03% to 96.13% line coverage (+7.1%)
- Increase branch coverage from 75.0% to 81.14% (+6.1%)
- Add comprehensive tests for Runner, Colors, OutputSections, XDGBaseDirectory
- Add error handling and confirmation prompt tests for PullAction and PushAction
- Suppress print output during tests for clean terminal output
- Update SimpleCov thresholds to 95% line / 80% branch

**Bug Fixes:**
- Fix XDGBaseDirectory path expansion to use ~ instead of $HOME literal
- Fix Colors accessor methods using wrong hash keys
- Fix OutputSections to hide differences_legend when only_mappings option is true
- Add nil config protection in Colors.load_custom_colors

**CI/CD:**
- Add SimpleCov coverage reporting to GitHub Actions workflow
- Display coverage summary in CI logs (line and branch percentages)
- Upload coverage HTML reports as artifacts with 30-day retention

**New Test Files:**
- spec/dotsync/runner_spec.rb (24 examples)
- spec/dotsync/colors_spec.rb (14 examples)
- spec/dotsync/actions/concerns/output_sections_spec.rb (11 examples)
- spec/dotsync/config/concerns/xdg_base_directory_spec.rb (8 examples)

Total: 323 examples, 0 failures, 2 pending

# 0.1.21

**New Features & Commands:**
- Add `status` command to show current configuration and mappings without executing actions
- Add `diff` command as convenient alias for preview mode (push without --apply)
- Add `init` command as alias for `setup` command
- Add `--version` flag to display version number
- Add `--dry-run` flag as explicit alias for preview mode (industry-standard terminology)
- Add `-y, --yes` flag to skip confirmation prompts for automation and scripting
- Add `-c, --config PATH` flag to specify custom config file path (enables multiple config workflows)

**Safety & User Experience:**
- Add confirmation prompt before applying changes showing file count and requiring explicit consent
- Confirmation can be bypassed with `--yes` flag or skipped in `--quiet` mode
- Improve error messages with actionable guidance for common issues (permissions, disk space, symlinks, type conflicts)
- Errors are now handled per-mapping, allowing processing to continue for other mappings
- Watch command now accepts and respects CLI options (--quiet, --no-legend, --no-mappings)

**Documentation:**
- Complete README overhaul documenting all CLI flags and command aliases
- Add comprehensive "Safety Features" section covering confirmation prompts, backups, and error handling
- Add "Command Options" section with all flags organized by category
- Add "Examples" section with 20+ practical usage patterns
- Enhance "Pro Tips" with guidance on multiple configs, automation, and command aliases
- Expand "Troubleshooting" section with solutions for confirmation prompts and config file management
- Update Table of Contents to include Safety Features section

**Developer Experience:**
- Add practical examples to CLI help text showing common usage patterns
- Improve help text organization with clearer command descriptions
- Better error handling for missing config file with actionable suggestions

# 0.1.20

**Robustness & Error Handling:**
- Add specific error classes for better error handling (`PermissionError`, `DiskFullError`, `SymlinkError`, `TypeConflictError`)
- Add symlink support with proper preservation of link targets (regular, broken, and relative symlinks)
- Add type conflict detection to prevent overwriting directories with files or vice versa
- Enhance FileTransfer error handling for permission issues and disk space errors

**Testing & Quality:**
- Add 16 new test cases covering edge cases and error scenarios
- Add comprehensive symlink handling tests (regular, broken, relative)
- Add path traversal security validation tests
- Add Unicode filename compatibility tests (Russian, Japanese, Chinese, emoji)
- Add empty directory transfer tests
- Add Mapping#apply_to tests for path handling and force flag preservation
- Improve content comparison tests to verify actual file changes
- Improve path validation tests with more edge cases
- Total test count increased from 136 to 152 examples

**Developer Experience:**
- All tests passing (152 examples, 0 failures)
- RuboCop compliant with no offenses

# 0.1.19

**Documentation & Testing:**
- Add comprehensive icons test suite with 40 test cases covering all icon functionality
- Add icons customization documentation section to README with complete examples
- Add "What is Dotsync?" overview section highlighting 7 key features
- Add Table of Contents for improved README navigation
- Add Quick Start guide with 5-step setup process
- Add Common Use Cases section with practical configuration examples (Neovim, Alacritty, shell configs)
- Add comprehensive Troubleshooting section covering 6 common issues and solutions
- Enhance Pro Tips section with 7 useful tips including environment variables and backup locations
- Add License and Ruby version badges to README
- Add IMPORTANT callout about --apply flag and preview mode behavior

**Bug Fixes:**
- Fix duplicate `src` typo in push/watch mapping examples (corrected to `dest`)
- Fix section title: "force and ignore" → "force, only, and ignore"
- Add defensive nil handling in `Icons.load_custom_icons` method

**Developer Experience:**
- Add AGENTS.md with AI agent guidelines for project development
- Improve user onboarding with clearer documentation and examples

# 0.1.18

- Add automatic version checking with non-intrusive upgrade prompts
- Version check runs once per 24 hours using cached timestamp
- Can be disabled with `DOTSYNC_NO_UPDATE_CHECK` environment variable
- Cache stored in XDG-compliant location (`~/.cache/dotsync/last_version_check`)

# 0.1.17

- Fixes skipped files
- FileTransfer: fixes options
- GithubActions: fixes generate release tag
- Avoid backup without no difference

# 0.1.16

- DirectoryDiffer: fixes path on removal difference
- MappingsTransfer: fixes "Differences" label text for clarity
- Add Difference Legend
- Show Difference Legend only if there are any difference
- OutputSections: added new options to hide output

# 0.1.15

- Readme: update screenshots in docs
- Consistent order of icons on Legend and Mappings
- DirectoryDiffer: implements only option
- Show Flags icons closer

# 0.1.14

- Render environment variables and mappings with a table
- Added mappings legend
- Added transfer files with "only" option

# 0.1.13

- PullAction: backup message simplified
- MappingsTransfer: show No differences

# 0.1.12

- FileTransfer: apply ignores both to src and dest
- DirectoryDiffer: fix diff on simple files
- PullAction: fix deletion older backup
- Readme: new screenshots

# 0.1.11

- Readme: fixes badge icon

# 0.1.10

- Readme: add screenshot for PushAction
- Readme: fixes character on sample config file

# 0.1.9

- Exe: improved banner with options
- Options: added "--apply"
- Options: added "--environment-variables"
- DirectoryDiffer: show full path using original mapping paths
- Readme: add gem version badge
- Readme: add requirements section

# 0.1.8

- Show full relative path on diff
- Show Diff section header

# 0.1.7

- Fixes broken runner

# 0.1.6

- Show diff changes on PushAction and PullAction.
- Fixed load custom config (Icons, Colors)

# 0.1.5

- Fixes backup when destination folder does not exist
- Add rubocop to Github Actions

# 0.1.4

- Colorized environment variables
- Fixed colorized mapping entries

# 0.1.3

- PushAction: Avoid error on missing destination
- Unify mappings print. Use icon for ignores presence.
- Extracted icons to its own module
- Reviewed icons
- Updated README with existing mapping entries icons
- Customizable icons
- Logger review

# 0.1.2

Add gem version on usage banner

# 0.1.1

Add gem executables

# 0.1.0

Initial version
