package config

import (
	"fmt"
	"strings"

	"github.com/dsaenztagarro/dotsync/internal/derr"
)

var validHookKeys = map[string]bool{"post_sync": true, "post_push": true, "post_pull": true}

// validate mirrors the direction config's validate! chain: the direction or
// [sync] must contribute mappings, per-mapping keys are checked, and hook keys
// are restricted.
func (c *Config) validate() error {
	if err := c.validateSectionOrSyncPresent(); err != nil {
		return err
	}
	if err := c.validateSectionMappings(); err != nil {
		return err
	}
	return c.validateSyncMappings()
}

func (c *Config) validateSectionOrSyncPresent() error {
	sec, _ := c.raw[c.dir.sectionName()].(map[string]any)
	hasSection := sec != nil && len(asMapSlice(sec["mappings"])) > 0
	if !hasSection && !c.hasSyncMappings() {
		return cfgErr("No [%s] mappings or [sync] mappings found in config file", c.dir.sectionName())
	}
	return nil
}

func (c *Config) hasSyncMappings() bool {
	sec, ok := c.raw["sync"].(map[string]any)
	if !ok {
		return false
	}
	if len(asMapSlice(sec["mappings"])) > 0 {
		return true
	}
	for _, name := range shorthandOrder {
		if len(asMapSlice(sec[name])) > 0 {
			return true
		}
	}
	return false
}

func (c *Config) validateSectionMappings() error {
	sec, ok := c.raw[c.dir.sectionName()].(map[string]any)
	if !ok {
		return nil
	}
	allowed := c.dir.sectionHookKey()
	for i, m := range asMapSlice(sec["mappings"]) {
		if !hasKey(m, "src") || !hasKey(m, "dest") {
			return cfgErr("Configuration error in %s mapping #%d: Each mapping must have 'src' and 'dest' keys.", c.dir.sectionName(), i+1)
		}
		if hm, ok := m["hooks"].(map[string]any); ok {
			var invalid []string
			for k := range hm {
				if k != allowed {
					invalid = append(invalid, k)
				}
			}
			if len(invalid) > 0 {
				return cfgErr("Configuration error in %s mapping #%d: Only '%s' hooks are allowed in [%s] mappings. Invalid key(s): %s",
					c.dir.sectionName(), i+1, allowed, c.dir.sectionName(), strings.Join(invalid, ", "))
			}
		}
	}
	return nil
}

func (c *Config) validateSyncMappings() error {
	secVal, present := c.raw["sync"]
	if !present {
		return nil
	}
	sec, ok := secVal.(map[string]any)
	if !ok {
		return cfgErr("Configuration error: [sync] must be a table, not an array. Use [[sync.mappings]] for explicit mappings.")
	}
	for i, m := range asMapSlice(sec["mappings"]) {
		if !hasKey(m, "local") || !hasKey(m, "remote") {
			return cfgErr("Configuration error in sync.mappings #%d: Each mapping must have 'local' and 'remote' keys.", i+1)
		}
		if err := validateHookKeys(m["hooks"], fmt.Sprintf("sync.mappings #%d", i+1)); err != nil {
			return err
		}
	}
	for _, name := range shorthandOrder {
		for i, m := range asMapSlice(sec[name]) {
			if err := validateHookKeys(m["hooks"], fmt.Sprintf("sync.%s #%d", name, i+1)); err != nil {
				return err
			}
		}
	}
	return nil
}

func validateHookKeys(v any, context string) error {
	hm, ok := v.(map[string]any)
	if !ok {
		return nil
	}
	var invalid []string
	for k := range hm {
		if !validHookKeys[k] {
			invalid = append(invalid, k)
		}
	}
	if len(invalid) > 0 {
		return cfgErr("Configuration error in %s: Invalid hook key(s): %s. Valid keys are: post_sync, post_push, post_pull",
			context, strings.Join(invalid, ", "))
	}
	return nil
}

func hasKey(m map[string]any, key string) bool {
	_, ok := m[key]
	return ok
}

func cfgErr(format string, args ...any) error {
	return &derr.ConfigError{Msg: "Config Error: " + fmt.Sprintf(format, args...)}
}
