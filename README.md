# Dotsync

[![Gem Version](https://badge.fury.io/rb/sidekiq.svg)](https://rubygems.org/gems/sidekiq)
[![Ruby Gem Test Status](https://github.com/dsaenztagarro/dotsync/actions/workflows/gem-push.yml/badge.svg)](https://github.com/dsaenztagarro/dotsync/actions)

> [!WARNING]
> This gem is under active development. You can expect new changes that may not be backward-compatible.

Welcome to Dotsync! This gem helps you manage and synchronize your dotfiles effortlessly. Below you'll find information on installation, usage, and some tips for getting started.

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

## Usage

### Executable Commands

Dotsync provides the following commands to manage your dotfiles:

- **Push**: Transfer dotfiles from your local machine to the destination repository.
  ```shell
  dotsync push
  ```

- **Pull**: Synchronize dotfiles from the repository to your local machine.
  ```shell
  dotsync pull
  ```

  During the `pull` operation, `Dotsync::PullAction` creates a backup of the existing files on the destination. These backups are stored in a directory under the XDG path, with each backup organized by a timestamp. To prevent excessive storage usage, only the 10 most recent backups are retained. Older backups are automatically purged, ensuring efficient storage management.

- **Watch**: Continuously monitor and sync changes between your local machine and the repository.
  ```shell
  dotsync watch
  ```

- **Setup**: Generate a default configuration file at `~/.config/dotsync.toml` with example mappings for `pull`, `push`, and `watch`.
  ```shell
  dotsync setup
  ```

### Configuration

The configuration file uses a `mappings` structure to define the source and destination of your dotfiles. Here is an example:

```toml
[[pull.mappings]]
src = "$XDG_CONFIG_HOME_MIRROR"
dest = "$XDG_CONFIG_HOME"

[[pull.mappings]]
src = "$HOME_MIRROR/.zshenv"
dest = "$HOME" }


[[push.mappings]]
src = "$HOME/.zshenv"
src = "$HOME_MIRROR/.zshenv"

[[push.mappings]]
src = "$XDG_CONFIG_HOME/alacritty"
dest = "$DOTFILES_DIR/config/alacritty"
force = true # it forces the deletion of destination folder
ignore = ["themes/rose-pine.toml"] # use relative paths to "dest" to ignore files and folders


[[watch.mappings]]
src = "$HOME/.zshenv"
src = "$HOME_MIRROR/.zshenv"

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

#### `force` and `ignore` Options in Mappings

Each mapping entry supports the following options:

- **`force`**: A boolean (true/false) value. When set to `true`, it forces deletion of the destination folder before transferring files from the source. This is particularly useful when you need to ensure that the destination is clean before a transfer.
- **`ignore`**: An array of patterns or file names to exclude during the transfer. This allows you to specify files or folders that should not be copied from the source to the destination.

These options apply when the source is a directory and are relevant for both `push` and `pull` operations.

### Rendering Mappings with Icons

When running `push` or `pull` actions, the mappings are rendered in the console with relevant icons to provide visual feedback on the status of each mapping. To correctly view these icons, ensure you are using a terminal that supports a patched [Nerd Font](https://www.nerdfonts.com). Below are some examples of how the mappings are displayed:

- **Force Icon**:
  ```
  Mappings:
    $DOTFILES_DIR/config/ → $XDG_CONFIG_HOME ⚡
  ```
  The ⚡ icon (`Dotsync::Icons::FORCE`) indicates that the `force` option is enabled and the destination folder will be cleared before the transfer.

- **Ignore Icon**:
  ```
  Mappings:
    $DOTFILES_DIR/home/.zshenv → $HOME 🚫
  ```
  The 🚫 icon (`Dotsync::Icons::IGNORE`) indicates that certain files or patterns are being ignored during the transfer.

- **Invalid Icon**:
  ```
  Mappings:
    $DOTFILES_DIR/home/.vimrc → $HOME ❌
  ```
  The ❌ icon (`Dotsync::Icons::INVALID`) indicates that the mapping is invalid due to missing source or destination paths.

### Pro Tips

- **Using rbenv**: To ensure the gem uses the correct Ruby version managed by rbenv, you can run:
  ```shell
  RBENV_VERSION=3.2.0 dotsync push
  ```

- **Global Installation**: Install the gem using a globally available Ruby version to make the executable accessible anywhere:
  ```shell
  gem install dotsync
  ```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dsaenztagarro/dotsync. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Dotsync project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/dsaenztagarro/dotsync/blob/master/CODE_OF_CONDUCT.md).
