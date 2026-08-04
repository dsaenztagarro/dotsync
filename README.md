# dotsync

> Manage dotfiles like a boss — keep your dotfiles in sync across machines from a single TOML file.

`dotsync` is a single, self-contained binary for synchronizing dotfiles between a machine and a mirror/repository, in either direction, with diff preview, backups, filtering, hooks, and a live-watch daemon. It has no runtime prerequisites — download the binary and run it on a fresh machine.

This is the **Go rewrite** of dotsync. The original Ruby gem lives at [`dsaenztagarro/dotsync-ruby`](https://github.com/dsaenztagarro/dotsync-ruby) and remains installable via `gem install dotsync` during the transition. See [`docs/architecture/decisions`](docs/architecture/decisions) for the rationale behind the rewrite.

## Status

Under active migration from the Ruby implementation. The engine (path matching, directory diffing, file transfer) and the `pull`/`push`/`watch` commands are being ported behind a differential harness that checks behavioral parity against the Ruby version.

## Development

```sh
go build ./cmd/dotsync   # build the binary
go test ./...            # run the test suite
```

## License

MIT © David Sáenz
