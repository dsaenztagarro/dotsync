package action

import (
	"io/fs"
	"os"
	"os/signal"
	"path/filepath"
	"strings"

	"github.com/fsnotify/fsnotify"

	"github.com/dsaenztagarro/dotsync/internal/fsutil"
	"github.com/dsaenztagarro/dotsync/internal/model"
	"github.com/dsaenztagarro/dotsync/internal/paths"
	"github.com/dsaenztagarro/dotsync/internal/transfer"
)

// watchTarget pairs a mapping with the directory watched for it. When pattern
// is non-empty the mapping's source is a single file and only that basename in
// base triggers a sync.
type watchTarget struct {
	m       *model.Mapping
	base    string
	pattern string
}

// Watch runs the live-watch daemon: it syncs changed source files to their
// destinations as they change, logging removals without propagating them, until
// interrupted. Ports WatchAction. fsnotify is non-recursive, so directories are
// registered recursively and newly created directories are added on the fly.
func (a *Action) Watch() error {
	a.opts.NonInteractive = true // the daemon must never block on a prompt
	a.mappings = a.cfg.Mappings()
	sec := computeSections(a.opts)

	a.ensureDestinations()
	if sec.mappingsLegend {
		a.showMappingsLegend()
	}
	if sec.mappings {
		a.showMappings()
	}
	if sec.invalidPaths {
		a.showInvalidPaths()
	}

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return err
	}
	defer watcher.Close()

	var targets []watchTarget
	for _, m := range a.mappings {
		if !m.Valid() {
			continue
		}
		src := m.Src()
		if fsutil.IsDir(src) {
			targets = append(targets, watchTarget{m: m, base: src})
			addRecursive(watcher, src)
		} else {
			base := filepath.Dir(src)
			targets = append(targets, watchTarget{m: m, base: base, pattern: filepath.Base(src)})
			_ = watcher.Add(base)
		}
	}

	if !a.opts.Quiet {
		a.log.Action("Listening for changes...", "")
		a.log.Action("Press Ctrl+C to exit.", "")
	}

	sigc := make(chan os.Signal, 1)
	signal.Notify(sigc, os.Interrupt)

	for {
		select {
		case <-sigc:
			a.log.Plain("")
			a.log.Action("Shutting down listeners...", "")
			return nil
		case event, ok := <-watcher.Events:
			if !ok {
				return nil
			}
			a.handleWatchEvent(watcher, targets, event)
		case werr, ok := <-watcher.Errors:
			if !ok {
				return nil
			}
			a.log.Error("Watch error: " + werr.Error())
		}
	}
}

func (a *Action) handleWatchEvent(watcher *fsnotify.Watcher, targets []watchTarget, event fsnotify.Event) {
	if event.Op&(fsnotify.Create|fsnotify.Write) != 0 {
		// A newly created directory must be watched so its files propagate.
		if event.Op&fsnotify.Create != 0 && fsutil.IsDir(event.Name) {
			addRecursive(watcher, event.Name)
			return
		}
		for _, t := range targets {
			if !underBase(event.Name, t.base) {
				continue
			}
			if t.pattern != "" {
				if filepath.Base(event.Name) != t.pattern {
					continue
				}
				// File mapping: re-sync the mapping's own file directly.
				a.log.Info("Copied file: "+decorate(t.m.OriginalSrc(), t.m.OriginalDest()), "")
				_ = transfer.New(t.m, nil).Run()
				continue
			}
			if t.m.Ignore(event.Name) || !fsutil.IsFile(event.Name) {
				continue
			}
			nm := t.m.ApplyTo(event.Name)
			a.log.Info("Copied file: "+decorate(nm.OriginalSrc(), nm.OriginalDest()), "")
			_ = transfer.New(nm, nil).Run()
		}
	}
	if event.Op&fsnotify.Remove != 0 {
		for _, t := range targets {
			if !underBase(event.Name, t.base) {
				continue
			}
			if t.pattern != "" && filepath.Base(event.Name) != t.pattern {
				continue
			}
			a.log.Info("File removed: "+event.Name, "")
			break
		}
	}
}

// addRecursive registers dir and all of its subdirectories with the watcher.
func addRecursive(watcher *fsnotify.Watcher, dir string) {
	_ = filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			_ = watcher.Add(path)
		}
		return nil
	})
}

func underBase(path, base string) bool {
	return strings.HasPrefix(path, base+string(filepath.Separator))
}

func decorate(src, dest string) string {
	return paths.ColorizeEnvVars(src) + " → " + paths.ColorizeEnvVars(dest)
}
