# Dotsync

[![Ruby Gem Test Status](https://github.com/dsaenztagarro/dotsync/actions/workflows/gem-push.yml/badge.svg)](https://github.com/dsaenztagarro/dotsync/actions)

Welcome to Dotsync! This gem helps you manage and synchronize your dotfiles effortlessly. Below you'll find information on installation, usage, and some tips for getting started.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dotsync'
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
[pull]
mappings = [
  { src = "$DOTFILES_DIR/config/", dest = "$XDG_CONFIG_HOME", force = false },
  { src = "$DOTFILES_DIR/home/.zshenv", dest = "$HOME" }
]

[push]
mappings = [
  { src = "$HOME/.zshenv", dest = "$DOTFILES_DIR/home/.zshenv" },
  { src = "$XDG_CONFIG_HOME/alacritty", dest = "$DOTFILES_DIR/config/alacritty" }
]

[watch]
mappings = [
  { src = "$HOME/.zshenv", dest = "$DOTFILES_DIR/home/.zshenv" },
  { src = "$XDG_CONFIG_HOME/alacritty", dest = "$DOTFILES_DIR/config/alacritty" }
]
```

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
