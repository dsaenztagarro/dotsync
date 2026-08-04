// Package config loads and resolves dotsync's TOML configuration and builds the
// direction-specific mapping list. It ports the Ruby loading pipeline
// (ConfigCache#resolve_config + ConfigMerger + SyncMappings) with one
// deliberate omission: the Marshal cache is dropped. A compiled binary parses
// this small TOML in sub-millisecond time, so the cache — and its whole class
// of mtime/size/version invalidation bugs — is unnecessary. DOTSYNC_NO_CACHE is
// still accepted as a no-op by the CLI for compatibility.
package config

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"

	"github.com/dsaenztagarro/dotsync/internal/derr"
	"github.com/dsaenztagarro/dotsync/internal/paths"
)

// Resolve loads the config at path and fully resolves it into a dynamic tree,
// applying `source` indirection and `include` deep-merge. Mirrors
// ConfigCache#resolve_config.
func Resolve(path string) (map[string]any, error) {
	raw, err := parseTOMLFile(path)
	if err != nil {
		return nil, err
	}
	if _, ok := raw["source"]; ok {
		return resolveSource(raw, path)
	}
	return resolveInclude(raw, path)
}

func parseTOMLFile(path string) (map[string]any, error) {
	var m map[string]any
	if _, err := toml.DecodeFile(path, &m); err != nil {
		return nil, &derr.ConfigError{Msg: "Config Error: failed to parse " + path + ": " + err.Error(), Err: err}
	}
	if m == nil {
		m = map[string]any{}
	}
	return normalizeMap(m), nil
}

// resolveSource handles a `source = "..."` pointer config, which must contain
// only that key and points at the real config file (which may itself `include`).
func resolveSource(raw map[string]any, configPath string) (map[string]any, error) {
	sv, ok := raw["source"].(string)
	if !ok {
		return nil, &derr.ConfigError{Msg: "Config Error: 'source' must be a string path"}
	}
	if len(raw) > 1 {
		return nil, &derr.ConfigError{Msg: "Config Error: 'source' cannot be combined with other keys. The source file should contain the full configuration."}
	}
	sourcePath := paths.ExpandPath(paths.ExpandEnvVars(sv))
	if !fileExists(sourcePath) {
		return nil, &derr.ConfigError{Msg: "Config Error: Source file not found: " + sourcePath}
	}
	sourceRaw, err := parseTOMLFile(sourcePath)
	if err != nil {
		return nil, err
	}
	if _, ok := sourceRaw["source"]; ok {
		return nil, &derr.ConfigError{Msg: "Config Error: Chained sources are not supported (found 'source' in " + sourcePath + ")"}
	}
	return resolveInclude(sourceRaw, sourcePath)
}

// resolveInclude applies an `include = "..."` deep-merge, mirroring
// ConfigMerger#resolve.
func resolveInclude(config map[string]any, configPath string) (map[string]any, error) {
	incVal, ok := config["include"]
	if !ok {
		return config, nil
	}
	incStr, ok := incVal.(string)
	if !ok {
		return nil, &derr.ConfigError{Msg: "Config Error: 'include' must be a string path"}
	}
	includePath := expandPathRel(incStr, filepath.Dir(configPath))
	if !fileExists(includePath) {
		return nil, &derr.ConfigError{Msg: "Config Error: Included file not found: " + includePath}
	}
	base, err := parseTOMLFile(includePath)
	if err != nil {
		return nil, err
	}
	if _, ok := base["include"]; ok {
		return nil, &derr.ConfigError{Msg: "Config Error: Chained includes are not supported (found 'include' in " + includePath + ")"}
	}
	overlay := make(map[string]any, len(config))
	for k, v := range config {
		if k != "include" {
			overlay[k] = v
		}
	}
	return deepMerge(base, overlay), nil
}

// deepMerge merges overlay onto base: hashes merge recursively, arrays
// concatenate (base first), scalars are overlaid. Mirrors ConfigMerger#deep_merge.
func deepMerge(base, overlay map[string]any) map[string]any {
	out := make(map[string]any, len(base))
	for k, v := range base {
		out[k] = v
	}
	for k, ov := range overlay {
		if bv, ok := out[k]; ok {
			if bm, ok1 := bv.(map[string]any); ok1 {
				if om, ok2 := ov.(map[string]any); ok2 {
					out[k] = deepMerge(bm, om)
					continue
				}
			}
			if ba, ok1 := bv.([]any); ok1 {
				if oa, ok2 := ov.([]any); ok2 {
					merged := make([]any, 0, len(ba)+len(oa))
					merged = append(merged, ba...)
					merged = append(merged, oa...)
					out[k] = merged
					continue
				}
			}
		}
		out[k] = ov
	}
	return out
}

// normalizeMap recursively normalizes a decoded TOML tree so that every table
// is map[string]any and every array (including arrays-of-tables, which
// BurntSushi decodes as []map[string]any) is []any. This lets deepMerge and the
// mapping accessors treat the tree uniformly.
func normalizeMap(m map[string]any) map[string]any {
	out := make(map[string]any, len(m))
	for k, v := range m {
		out[k] = normalize(v)
	}
	return out
}

func normalize(v any) any {
	switch t := v.(type) {
	case map[string]any:
		return normalizeMap(t)
	case []map[string]any:
		s := make([]any, len(t))
		for i, e := range t {
			s[i] = normalizeMap(e)
		}
		return s
	case []any:
		s := make([]any, len(t))
		for i, e := range t {
			s[i] = normalize(e)
		}
		return s
	default:
		return t
	}
}

// expandPathRel mirrors File.expand_path(value, baseDir): ~ expands against the
// home dir, absolute values stand alone, relative values resolve against baseDir.
func expandPathRel(value, baseDir string) string {
	if strings.HasPrefix(value, "~") {
		return paths.ExpandPath(value)
	}
	if filepath.IsAbs(value) {
		return filepath.Clean(value)
	}
	return filepath.Clean(filepath.Join(baseDir, value))
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}
