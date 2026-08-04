package config

import (
	"os"
	"path/filepath"

	"github.com/dsaenztagarro/dotsync/internal/derr"
	"github.com/dsaenztagarro/dotsync/internal/paths"
)

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
	abs := paths.ExpandPath(path)
	if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
		return "", &derr.ConfigError{Msg: "Config Error: could not create config directory: " + err.Error(), Err: err}
	}
	if err := os.WriteFile(abs, []byte(defaultConfigTemplate), 0o644); err != nil {
		return "", &derr.ConfigError{Msg: "Config Error: could not write config file: " + err.Error(), Err: err}
	}
	return abs, nil
}
