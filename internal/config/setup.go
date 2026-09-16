package config

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/dsaenztagarro/dotsync/internal/derr"
	"github.com/dsaenztagarro/dotsync/internal/paths"
)

// sourcePointerTemplate is the whole of a pointer config: `source` must be the
// only key, so there is nothing else to put in it.
const sourcePointerTemplate = `# dotsync configuration pointer
# The real configuration lives in the dotfiles repository and is read from
# there, so an edit governs the very next run. Keep this file as-is.
source = "%s"
`

const defaultConfigTemplate = `# dotsync configuration
# See https://github.com/dsaenztagarro/dotsync for the full reference.
#
# Point a mirror location (your dotfiles repo) at environment variables such as
# $XDG_CONFIG_HOME_MIRROR, then map paths below.

# Optional: override diff colors (256-color indices) and icons.
# [colors]
# diff_additions = 34
# [icons]
# force = "!"

# Bidirectional mappings: "dotsync push" copies local -> remote,
# "dotsync pull" copies remote -> local.
[[sync.mappings]]
local  = "$XDG_CONFIG_HOME/nvim"
remote = "$XDG_CONFIG_HOME_MIRROR/nvim"

# XDG shorthand: expands to
#   $XDG_CONFIG_HOME/<path> <-> $XDG_CONFIG_HOME_MIRROR/<path>
# [[sync.xdg_config]]
# path = "alacritty"
# force = true
`

// WriteDefault writes a starter configuration to path (expanding ~), creating
// parent directories as needed, and returns the absolute path written.
func WriteDefault(path string) (string, error) {
	return write(path, defaultConfigTemplate)
}

// WriteSourcePointer writes a pointer config: a file whose only key is `source`,
// naming the authoritative configuration in a dotfiles repository. dotsync then
// reads the repo copy directly, so a rule takes effect on the run that follows
// the edit rather than the run after the one that delivered it.
//
// sourcePath is written absolute on purpose. A run started by a LaunchAgent,
// a cron job or a systemd unit inherits no shell profile, so the mirror
// variables a login shell exports are not set there and a "$VAR"-relative
// pointer would resolve somewhere else.
func WriteSourcePointer(path, sourcePath string) (string, error) {
	abs := paths.ExpandPath(paths.ExpandEnvVars(sourcePath))
	if !fileExists(abs) {
		return "", &derr.ConfigError{Msg: "Config Error: Source file not found: " + abs}
	}
	return write(path, fmt.Sprintf(sourcePointerTemplate, abs))
}

// write creates a config file, refusing to replace one that already exists: a
// setup command that silently overwrote a working configuration would destroy
// the very thing it is meant to bootstrap.
func write(path, content string) (string, error) {
	abs := paths.ExpandPath(path)
	if fileExists(abs) {
		return "", &derr.ConfigError{Msg: fmt.Sprintf(
			"Config Error: %s already exists.\n\nRemove it first, or pass -c to write elsewhere.", abs)}
	}
	if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
		return "", &derr.ConfigError{Msg: "Config Error: could not create config directory: " + err.Error(), Err: err}
	}
	if err := os.WriteFile(abs, []byte(content), 0o644); err != nil {
		return "", &derr.ConfigError{Msg: "Config Error: could not write config file: " + err.Error(), Err: err}
	}
	return abs, nil
}
