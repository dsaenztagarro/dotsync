#!/usr/bin/env bash
#
# Differential parity harness: runs the Ruby oracle (`dotsync`, the original
# gem) and the Go binary against IDENTICAL fixtures, then diffs the resulting
# destination trees (path + type + mode + content-hash + symlink target). Any
# difference is a parity regression.
#
# This is a LOCAL tool, not part of CI: it requires the Ruby `dotsync` gem
# installed on PATH as the oracle. CI runs the Go unit tests instead.
#
# Usage:  script/parity.sh
# Requires: the `dotsync` Ruby gem on PATH, and Go.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

RUBY_BIN="${DOTSYNC_RUBY:-dotsync}"
GO_BIN="$WORK/dotsync-go"

if ! command -v "$RUBY_BIN" >/dev/null 2>&1; then
  echo "error: Ruby oracle '$RUBY_BIN' not found on PATH (set DOTSYNC_RUBY)." >&2
  exit 2
fi
( cd "$ROOT" && go build -o "$GO_BIN" ./cmd/dotsync )

# Common environment: no cache, no update check, no color — deterministic runs.
run_engine() { # <bin> <dir>
  local bin="$1" dir="$2"
  DOTSYNC_NO_CACHE=1 DOTSYNC_NO_UPDATE_CHECK=1 NO_COLOR=1 \
    XDG_DATA_HOME="$dir/xdg" XDG_CONFIG_HOME="$dir/cfg" \
    "$bin" pull --apply --yes -c "$dir/config.toml" >/dev/null 2>&1 || true
}

# snapshot <dest-dir> -> normalized, sorted description of the tree.
snapshot() {
  local dest="$1"
  ( cd "$dest" && find . \( -type f -o -type l \) | LC_ALL=C sort | while read -r f; do
      if [ -L "$f" ]; then
        printf '%s\tsymlink\t%s\n' "$f" "$(readlink "$f")"
      else
        printf '%s\tfile\t%s\t%s\n' "$f" "$(stat -f '%Lp' "$f")" "$(shasum -a 256 "$f" | awk '{print $1}')"
      fi
    done )
}

PASS=0
FAIL=0

# scenario <name> <setup-fn>: builds identical fixtures for each engine, runs
# both, and diffs the destination trees.
scenario() {
  local name="$1" setup="$2"
  local rdir="$WORK/$name/ruby" gdir="$WORK/$name/go"
  mkdir -p "$rdir" "$gdir"
  "$setup" "$rdir"
  "$setup" "$gdir"
  run_engine "$RUBY_BIN" "$rdir"
  run_engine "$GO_BIN" "$gdir"
  if diff <(snapshot "$rdir/local") <(snapshot "$gdir/local") >"$WORK/$name.diff"; then
    printf '  PASS  %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %s\n' "$name"
    sed 's/^/        /' "$WORK/$name.diff"
    FAIL=$((FAIL + 1))
  fi
}

pull_config() { # <dir> <extra toml lines>
  cat >"$1/config.toml" <<EOF
[[pull.mappings]]
src = "$1/remote"
dest = "$1/local"
$2
EOF
}

setup_force() {
  local d="$1"
  mkdir -p "$d/remote/fold" "$d/local/fold"
  printf 'new\n' >"$d/remote/fold/keep.txt"
  printf 'added\n' >"$d/remote/fold/added.txt"
  printf 'old\n' >"$d/local/fold/keep.txt"
  printf 'stale\n' >"$d/local/fold/removed.txt"
  pull_config "$d" "force = true"
}

setup_only() {
  local d="$1"
  mkdir -p "$d/remote/bundle" "$d/remote/cabal" "$d/local"
  printf 'bundle\n' >"$d/remote/bundle/config"
  printf 'other\n' >"$d/remote/bundle/other.txt"
  printf 'cabal\n' >"$d/remote/cabal/config"
  pull_config "$d" 'only = ["bundle/config"]'
}

setup_ignore() {
  local d="$1"
  mkdir -p "$d/remote/keep" "$d/remote/skip" "$d/local"
  printf 'a\n' >"$d/remote/keep/a.txt"
  printf 'b\n' >"$d/remote/skip/b.txt"
  printf 'c\n' >"$d/remote/top.txt"
  pull_config "$d" 'ignore = ["skip", "top.txt"]'
}

setup_symlink() {
  local d="$1"
  mkdir -p "$d/remote" "$d/local"
  printf 'target\n' >"$d/remote/real.txt"
  ln -s real.txt "$d/remote/rel_link"
  ln -s /nonexistent/path "$d/remote/broken_link"
  pull_config "$d" "force = true"
}

setup_glob() {
  local d="$1"
  mkdir -p "$d/remote" "$d/local"
  printf 'brew\n' >"$d/remote/local.brew.plist"
  printf 'notes\n' >"$d/remote/local.notes.plist"
  printf 'apple\n' >"$d/remote/com.apple.finder.plist"
  pull_config "$d" 'only = ["local.*.plist"]'
}

echo "dotsync parity: Ruby oracle ($("$RUBY_BIN" --version)) vs Go binary"
scenario force "setup_force"
scenario only "setup_only"
scenario ignore "setup_ignore"
scenario symlink "setup_symlink"
scenario glob "setup_glob"

echo "----"
echo "parity: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
