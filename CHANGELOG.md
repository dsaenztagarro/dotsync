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
