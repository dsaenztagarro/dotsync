# Coding Agent Guidelines

## Commands
- Run all tests: `rake spec` or `bundle exec rspec`
- Run single test: `bundle exec rspec spec/path/to/file_spec.rb` or `bundle exec rspec spec/path/to/file_spec.rb:42`
- Lint: `bundle exec rubocop` (auto-fix: `bundle exec rubocop -a`)
- Build gem: `rake build`

## Code Style
- **Ruby version**: >= 3.2.0
- **Frozen string literal**: Always include `# frozen_string_literal: true` at top of files
- **Indentation**: 2 spaces, no tabs
- **Strings**: Double quotes (`"string"`)
- **Hash syntax**: Modern style (`{ a: 1 }`)
- **Method definitions**: Always use parentheses for methods with parameters
- **Spacing**: Space after colons, commas, around operators; `foo { bar }` not `foo {bar}`

## Project Structure
- Actions: `lib/dotsync/actions/` - Core operations (PullAction, PushAction, WatchAction)
- Config: `lib/dotsync/config/` - Configuration management with XDG support
- Models: `lib/dotsync/models/` - Domain models (Mapping, Diff)
- Utils: `lib/dotsync/utils/` - Helpers (FileTransfer, DirectoryDiffer, Logger, PathUtils)
- Tests: `spec/` - RSpec tests mirroring lib structure

## Error Handling
- Use custom errors from `lib/dotsync/errors.rb`: `ConfigError`, `FileTransferError`, `PermissionError`, `DiskFullError`, `SymlinkError`, `TypeConflictError`
- Always use `raise ErrorClass, "message"` for explicit error handling
