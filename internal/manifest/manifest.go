// Package manifest tracks which files an `only`-filtered mapping previously
// synced, so orphans (files dropped from the filter) can be removed on pull
// without force mode. Ports Dotsync::Manifest (a JSON file per shorthand key).
package manifest

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
)

const manifestsDir = "dotsync/manifests"

// Manifest is the record for one mapping's destination, keyed by manifest key.
type Manifest struct {
	destDir      string
	manifestPath string
}

// New builds a Manifest at $xdgDataHome/dotsync/manifests/<key>.json.
func New(destDir, key, xdgDataHome string) *Manifest {
	return &Manifest{
		destDir:      destDir,
		manifestPath: filepath.Join(xdgDataHome, manifestsDir, key+".json"),
	}
}

type doc struct {
	Files []string `json:"files"`
}

// Read returns the relative file paths recorded in the manifest, or nil.
func (m *Manifest) Read() []string {
	data, err := os.ReadFile(m.manifestPath)
	if err != nil {
		return nil
	}
	var d doc
	if json.Unmarshal(data, &d) != nil {
		return nil
	}
	return d.Files
}

// Write records the current relative file list (sorted).
func (m *Manifest) Write(files []string) error {
	sorted := append([]string(nil), files...)
	sort.Strings(sorted)
	if err := os.MkdirAll(filepath.Dir(m.manifestPath), 0o755); err != nil {
		return err
	}
	b, err := json.MarshalIndent(doc{Files: sorted}, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(m.manifestPath, b, 0o644)
}

// Orphans returns absolute paths that were recorded previously but are no longer
// in currentFiles.
func (m *Manifest) Orphans(currentFiles []string) []string {
	current := make(map[string]bool, len(currentFiles))
	for _, f := range currentFiles {
		current[f] = true
	}
	var orphans []string
	for _, f := range m.Read() {
		if !current[f] {
			orphans = append(orphans, filepath.Join(m.destDir, f))
		}
	}
	return orphans
}
