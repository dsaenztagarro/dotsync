package config

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/dsaenztagarro/dotsync/internal/derr"
	"github.com/dsaenztagarro/dotsync/internal/model"
	"github.com/dsaenztagarro/dotsync/internal/paths"
)

// Direction selects push (local -> remote) or pull (remote -> local) semantics.
type Direction int

const (
	Push Direction = iota
	Pull
)

// String names the direction the way the CLI and the cockpit refer to it.
func (d Direction) String() string {
	if d == Push {
		return "push"
	}
	return "pull"
}

func (d Direction) sectionName() string {
	if d == Push {
		return "push"
	}
	return "pull"
}

func (d Direction) sectionHookKey() string {
	if d == Push {
		return "post_push"
	}
	return "post_pull"
}

// shorthandOrder and shorthands mirror SyncMappings::SHORTHANDS. The order is
// significant: it determines the order shorthand mappings appear in the final
// list, and Go maps do not preserve insertion order.
var shorthandOrder = []string{"home", "xdg_config", "xdg_data", "xdg_cache", "xdg_bin"}

var shorthands = map[string][2]string{ // [local, remote]
	"home":       {"$HOME", "$HOME_MIRROR"},
	"xdg_config": {"$XDG_CONFIG_HOME", "$XDG_CONFIG_HOME_MIRROR"},
	"xdg_data":   {"$XDG_DATA_HOME", "$XDG_DATA_HOME_MIRROR"},
	"xdg_cache":  {"$XDG_CACHE_HOME", "$XDG_CACHE_HOME_MIRROR"},
	"xdg_bin":    {"$XDG_BIN_HOME", "$XDG_BIN_HOME_MIRROR"},
}

// Config is a resolved, validated configuration for one sync direction.
type Config struct {
	raw         map[string]any
	dir         Direction
	sectionName string // the [<section>.mappings] table to read (push/pull/watch)
	prov        Provenance
}

// DefaultConfigPath mirrors ENV["DOTSYNC_CONFIG"] || "~/.config/dotsync.toml".
func DefaultConfigPath() string {
	if v := os.Getenv("DOTSYNC_CONFIG"); v != "" {
		return v
	}
	return "~/.config/dotsync.toml"
}

// Load resolves and validates the config for a direction. Mirrors
// BaseConfig#initialize, including the missing-file "run dotsync setup" hint.
func Load(path string, dir Direction) (*Config, error) {
	return load(path, dir, dir.sectionName())
}

// LoadWatch loads the config for the watch daemon: push orientation, but the
// [watch] section supplies the section mappings (mirrors WatchActionConfig).
func LoadWatch(path string) (*Config, error) {
	return load(path, Push, "watch")
}

func load(path string, dir Direction, sectionName string) (*Config, error) {
	abs := paths.ExpandPath(path)
	if !fileExists(abs) {
		return nil, &derr.ConfigError{Msg: fmt.Sprintf(
			"Config file not found: %s\n\nTo create a default configuration file, run:\n  dotsync setup", abs)}
	}
	raw, prov, err := Resolve(abs)
	if err != nil {
		return nil, err
	}
	c := &Config{raw: raw, dir: dir, sectionName: sectionName, prov: prov}
	if err := c.validate(); err != nil {
		return nil, err
	}
	return c, nil
}

// Raw exposes the resolved tree (for [icons]/[colors] overrides).
func (c *Config) Raw() map[string]any { return c.raw }

// Path is the file dotsync was pointed at. Under `source` this is the pointer,
// not the configuration anyone edits — use EffectivePath for that.
func (c *Config) Path() string { return c.prov.HostPath }

// Provenance names every file on disk that produced this configuration.
func (c *Config) Provenance() Provenance { return c.prov }

// EffectivePath is the file a user edits to change this configuration.
func (c *Config) EffectivePath() string { return c.prov.EffectivePath() }

// Mappings returns the direction's mappings: the [[push|pull.mappings]] section
// mappings first, then the [sync] mappings (explicit, then shorthands in order).
func (c *Config) Mappings() []*model.Mapping {
	return append(c.sectionMappings(), c.syncMappings()...)
}

func (c *Config) sectionMappings() []*model.Mapping {
	sec, ok := c.raw[c.sectionName].(map[string]any)
	if !ok {
		return nil
	}
	var out []*model.Mapping
	for _, m := range asMapSlice(sec["mappings"]) {
		out = append(out, model.New(model.Attributes{
			Src:    getString(m, "src"),
			Dest:   getString(m, "dest"),
			Force:  getBool(m, "force"),
			Ignore: toStringSlice(m["ignore"]),
			Only:   toStringSlice(m["only"]),
			Hooks:  sectionHooks(m["hooks"], c.dir.sectionHookKey()),
		}))
	}
	return out
}

func (c *Config) syncMappings() []*model.Mapping {
	sec, ok := c.raw["sync"].(map[string]any)
	if !ok {
		return nil
	}
	var out []*model.Mapping

	// Explicit [[sync.mappings]] with local/remote keys.
	for _, m := range asMapSlice(sec["mappings"]) {
		src, dest := c.orient(getString(m, "local"), getString(m, "remote"))
		out = append(out, model.New(model.Attributes{
			Src:    src,
			Dest:   dest,
			Force:  getBool(m, "force"),
			Ignore: toStringSlice(m["ignore"]),
			Only:   toStringSlice(m["only"]),
			Hooks:  c.syncHooks(m["hooks"]),
		}))
	}

	// Shorthands ([[sync.<type>]]), in the canonical order.
	for _, name := range shorthandOrder {
		def := shorthands[name]
		for _, m := range asMapSlice(sec[name]) {
			path := getString(m, "path")
			src, dest := c.orient(buildPath(def[0], path), buildPath(def[1], path))
			out = append(out, model.New(model.Attributes{
				Src:      src,
				Dest:     dest,
				Force:    getBool(m, "force"),
				Ignore:   toStringSlice(m["ignore"]),
				Only:     toStringSlice(m["only"]),
				Hooks:    c.syncHooks(m["hooks"]),
				SyncType: name,
			}))
		}
	}
	return out
}

// orient maps a (local, remote) pair to (src, dest) for the direction.
func (c *Config) orient(local, remote string) (src, dest string) {
	if c.dir == Push {
		return local, remote
	}
	return remote, local
}

// syncHooks resolves [sync] hooks: post_sync always, plus the direction's hook.
func (c *Config) syncHooks(v any) []string {
	hm, ok := v.(map[string]any)
	if !ok {
		return nil
	}
	hooks := toStringSlice(hm["post_sync"])
	hooks = append(hooks, toStringSlice(hm[c.dir.sectionHookKey()])...)
	return hooks
}

// --- XDG base directories (File.expand_path(ENV[...] || default)) ---

func xdgDir(env, def string) string {
	if v := os.Getenv(env); v != "" {
		return paths.ExpandPath(v)
	}
	return paths.ExpandPath(def)
}

func xdgDataHome() string { return xdgDir("XDG_DATA_HOME", "~/.local/share") }

// BackupsRoot is where pull writes timestamped backups.
func (c *Config) BackupsRoot() string { return filepath.Join(xdgDataHome(), "dotsync", "backups") }

// ManifestsRoot is the XDG data home under which orphan manifests live.
func (c *Config) ManifestsRoot() string { return xdgDataHome() }

// --- helpers ---

func sectionHooks(v any, key string) []string {
	hm, ok := v.(map[string]any)
	if !ok {
		return nil
	}
	return toStringSlice(hm[key])
}

func buildPath(base, path string) string {
	if path == "" {
		return base
	}
	return filepath.Join(base, path)
}

func asMapSlice(v any) []map[string]any {
	switch t := v.(type) {
	case []any:
		out := make([]map[string]any, 0, len(t))
		for _, e := range t {
			if m, ok := e.(map[string]any); ok {
				out = append(out, m)
			}
		}
		return out
	case map[string]any:
		return []map[string]any{t}
	default:
		return nil
	}
}

func getString(m map[string]any, key string) string {
	if s, ok := m[key].(string); ok {
		return s
	}
	return ""
}

func getBool(m map[string]any, key string) bool {
	if b, ok := m[key].(bool); ok {
		return b
	}
	return false
}

// toStringSlice mirrors Ruby's Array(x) for string-or-array values: a string
// becomes a one-element slice, an array keeps its string elements, nil -> nil.
func toStringSlice(v any) []string {
	switch t := v.(type) {
	case string:
		return []string{t}
	case []any:
		out := make([]string, 0, len(t))
		for _, e := range t {
			if s, ok := e.(string); ok {
				out = append(out, s)
			}
		}
		return out
	default:
		return nil
	}
}
