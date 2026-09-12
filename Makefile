# dotsync developer entrypoints. See https://www.gnu.org/software/make/manual/make.html
#
# Deliberately thin. `go build`, `go test ./...` and `go vet ./...` are already
# the shortest way to run themselves and get no aliases here; what earns a
# target is an invocation that is either impossible to remember (the version
# ldflags) or quietly easy to get wrong (`gofmt -l` exits 0 even when it names
# unformatted files, so a run that looks green can be red).

BIN := dotsync
CMD := ./cmd/dotsync

# Where `install` puts the binary. Mirrors the convention the dotfiles repo
# uses for its own compiled helpers.
PREFIX ?= $(or $(XDG_BIN_HOME),$(HOME)/.local/bin)

# The release this working tree is built from. Resolved once, at parse time.
# Strip the leading `v`: the tags carry it, `dotsync --version` does not.
GIT_VERSION := $(shell git describe --tags --dirty 2>/dev/null | sed 's/^v//')
VERSION ?= $(GIT_VERSION)

# No tags, or no git at all (a source tarball), leaves VERSION empty and so
# passes no -X at all. That is deliberate rather than a gap: main.go treats an
# empty injection as "keep what is compiled in", so the constant in
# internal/cli stands and the binary still reports a real release instead of a
# blank. Injecting an empty string would be the broken case, not this.
LDFLAGS := $(if $(VERSION),-ldflags '-X main.version=$(VERSION)')

.PHONY: build install gate parity help
.DEFAULT_GOAL := help

# Build into the working directory. Use this over a bare `go build`: without
# the ldflags the binary reports the version compiled into internal/cli, which
# is the previous release on every commit after a tag.
build:
	go build $(LDFLAGS) -o $(BIN) $(CMD)
	@echo "built ./$(BIN) ($(if $(VERSION),$(VERSION),compiled-in version))"

# Build with the version injected, straight into $PREFIX. This is the install
# path until GoReleaser publishes archives and a Homebrew tap.
install:
	@mkdir -p "$(PREFIX)"
	go build $(LDFLAGS) -o "$(PREFIX)/$(BIN)" $(CMD)
	@echo "installed $(PREFIX)/$(BIN) ($(if $(VERSION),$(VERSION),compiled-in version))"

# The ship gate from AGENTS.md, in the order CI runs it. CI calls this target
# rather than restating the four checks, so there is one definition of "green"
# and it cannot drift from what you run locally. The build writes to /dev/null
# because the gate only asks whether it compiles, not for an artifact.
gate:
	@unformatted="$$(gofmt -l .)"; \
	 if [ -n "$$unformatted" ]; then \
	   echo "not gofmt-clean:" >&2; \
	   echo "$$unformatted" >&2; \
	   exit 1; \
	 fi
	go vet ./...
	go test ./...
	go build -o /dev/null $(CMD)

# The differential harness against the Ruby oracle, required for
# parity-affecting changes. Kept out of `gate` because it needs the Ruby gem on
# PATH, which CI does not have; set DOTSYNC_RUBY if the oracle is not `dotsync`.
parity:
	script/parity.sh

help:
	@echo "Makefile targets:"
	@echo "* build    - build ./$(BIN) with the version injected"
	@echo "* install  - build and install into \$$PREFIX ($(PREFIX))"
	@echo "* gate     - the full ship gate: gofmt, vet, test, build (what CI runs)"
	@echo "* parity   - differential harness vs the Ruby oracle (needs the gem on PATH)"
