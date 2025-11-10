# Agents

This document describes AI agents and automation helpers that can assist with developing and maintaining the Dotsync project.

## Development Agents

### Code Review Agent

**Purpose**: Review code changes for quality, consistency, and adherence to Ruby best practices.

**When to use**:
- Before submitting pull requests
- After implementing new features
- When refactoring existing code

**What it checks**:
- Ruby style guide compliance (follows .rubocop.yml)
- Test coverage for new functionality
- Proper error handling
- Documentation completeness
- Performance considerations

### Test Generation Agent

**Purpose**: Generate and enhance RSpec tests for Dotsync functionality.

**When to use**:
- When adding new actions or utilities
- When test coverage is insufficient
- When refactoring existing code

**Focus areas**:
- Unit tests for models (Mapping, Diff)
- Integration tests for actions (PullAction, PushAction, WatchAction)
- Edge cases and error scenarios
- File system operations

### Documentation Agent

**Purpose**: Maintain and improve project documentation.

**When to use**:
- After adding new features
- When configuration options change
- When updating usage examples

**Responsibilities**:
- Keep README.md synchronized with code
- Update inline code documentation
- Maintain CHANGELOG.md
- Generate usage examples

## Maintenance Agents

### Dependency Update Agent

**Purpose**: Monitor and suggest updates for gem dependencies.

**What it monitors**:
- Security vulnerabilities in dependencies
- New versions of runtime and development dependencies
- Ruby version compatibility

### Release Agent

**Purpose**: Assist with the release process following RELEASING.md guidelines.

**Checklist**:
- Version number updated in version.rb
- CHANGELOG.md updated with changes
- Tests passing
- RuboCop compliance
- Tag creation and push
- Gem publication to rubygems.org

## Usage

To work with these agents effectively:

1. **Be specific**: Provide clear context about what you're working on
2. **Reference files**: Point to specific files or line numbers when discussing issues
3. **Run tests**: Always run `rake spec` after changes
4. **Follow conventions**: Adhere to existing code patterns and Ruby style guide

## Contributing

When working with agents on this project:

- Review generated code carefully before committing
- Ensure all tests pass (`rake spec`)
- Run RuboCop (`bundle exec rubocop`)
- Update documentation as needed
- Follow the project's [Code of Conduct](CODE_OF_CONDUCT.md)
