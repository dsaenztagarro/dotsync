// Package action orchestrates a push or pull: it computes each valid mapping's
// diff once (memoized), renders the quiet-by-default output sections, and on
// --apply runs the confirmation, backups (pull), transfer, orphan cleanup
// (pull), and hooks. It ports Dotsync::MappingsTransfer plus PushAction/PullAction.
package action

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/dsaenztagarro/dotsync/internal/config"
	"github.com/dsaenztagarro/dotsync/internal/derr"
	"github.com/dsaenztagarro/dotsync/internal/engine"
	"github.com/dsaenztagarro/dotsync/internal/fsutil"
	"github.com/dsaenztagarro/dotsync/internal/hook"
	"github.com/dsaenztagarro/dotsync/internal/manifest"
	"github.com/dsaenztagarro/dotsync/internal/model"
	"github.com/dsaenztagarro/dotsync/internal/paths"
	"github.com/dsaenztagarro/dotsync/internal/render"
	"github.com/dsaenztagarro/dotsync/internal/transfer"
)

// Options carries the parsed CLI flags that affect a run.
type Options struct {
	Apply          bool
	Yes            bool
	Quiet          bool
	Verbose        bool
	CreateDest     bool
	ForceHooks     bool
	Legend         bool
	ShowMappings   bool
	ShowEnv        bool
	ShowOptions    bool
	OnlyDiff       bool
	OnlyConfig     bool
	OnlyMappings   bool
	DiffContent    bool
	NonInteractive bool // watch: honor --create-dest but never prompt

	Command string // the invoked command name, for the cockpit's header
	TUI     bool   // render the interactive cockpit instead of classic lines
}

// Action runs one direction end-to-end.
type Action struct {
	cfg    *config.Config
	dir    config.Direction
	log    *render.Logger
	colors render.Colors
	icons  render.Icons
	opts   Options
	stdin  io.Reader

	mappings []*model.Mapping

	valid         []*model.Mapping
	diffs         []engine.Diff
	diffsComputed bool

	backupRootPath string
}

// New builds an Action.
func New(cfg *config.Config, dir config.Direction, log *render.Logger, colors render.Colors, icons render.Icons, opts Options, stdin io.Reader) *Action {
	return &Action{cfg: cfg, dir: dir, log: log, colors: colors, icons: icons, opts: opts, stdin: stdin}
}

var invalidityMessages = map[model.InvalidityReason][2]string{
	model.SrcMissing:  {"source does not exist", "check config or pull first"},
	model.DestMissing: {"destination directory does not exist", "--create-dest"},
	model.PathsSame:   {"source and destination are the same", "check config"},
	model.PathsNested: {"source and destination are nested", "check config"},
}

// Execute mirrors PushAction/PullAction#execute.
func (a *Action) Execute() error {
	a.mappings = a.cfg.Mappings()
	if a.opts.TUI {
		return a.executeTUI()
	}
	sec := computeSections(a.opts)

	if sec.options {
		a.showOptions()
	}
	if sec.envVars {
		a.showEnvVars()
	}
	a.reportCreatedDestinations(a.ensureDestinations())
	if sec.mappingsLegend {
		a.showMappingsLegend()
	}
	if sec.mappings {
		a.showMappings()
	}
	if sec.invalidPaths {
		a.showInvalidPaths()
	}
	if sec.selfRefConfig {
		a.showSelfReferentialConfig()
	}
	if err := a.computeDiffs(); err != nil {
		return err
	}
	if a.hasDifferences() && sec.differencesLegend {
		a.showDifferencesLegend()
	}
	if sec.differences {
		a.showDifferences()
	}
	if sec.differences {
		a.showHooksPreview(a.opts.ForceHooks)
	}

	if !a.opts.Apply {
		return nil
	}

	if a.hasDifferences() && !a.opts.Yes && !a.opts.Quiet {
		if !a.confirmAction() {
			return nil
		}
	}

	if a.dir == config.Pull && a.hasDifferences() {
		if a.createBackup() {
			a.showBackup()
			a.purgeOldBackups()
		}
	}

	if a.hasDifferences() {
		a.transferMappings()
		if a.dir == config.Pull {
			a.cleanupOrphans()
		}
		a.executeHooks(a.opts.ForceHooks)
	} else if a.opts.ForceHooks {
		a.executeHooks(true)
	}

	if a.dir == config.Pull {
		a.log.Action("Mappings pulled", "")
	} else {
		a.log.Action("Mappings pushed", "")
	}
	return nil
}

// --- diff computation (memoized, after ensureDestinations) ---

func (a *Action) computeDiffs() error {
	if a.diffsComputed {
		return nil
	}
	for _, m := range a.mappings {
		if m.Valid() {
			a.valid = append(a.valid, m)
		}
	}
	a.diffs = make([]engine.Diff, len(a.valid))
	for i, m := range a.valid {
		d, err := engine.New(m).Diff()
		if err != nil {
			return err
		}
		a.diffs[i] = d
	}
	a.diffsComputed = true
	return nil
}

func (a *Action) hasDifferences() bool {
	for _, d := range a.diffs {
		if d.Any() {
			return true
		}
	}
	return false
}

// --- output sections ---

func (a *Action) showOptions() {
	a.log.Info("Options:", "")
	applyStr := "FALSE"
	if a.opts.Apply {
		applyStr = "TRUE"
	}
	a.log.Plain("  Apply: " + applyStr)
	if a.opts.ForceHooks {
		a.log.Plain("  Force hooks: TRUE")
	}
	a.log.Plain("")
}

func (a *Action) showEnvVars() {
	names := a.mappingsEnvVars()
	if len(names) == 0 {
		return
	}
	a.log.Info("Environment variables:", "")
	sort.Strings(names)
	for _, name := range names {
		a.log.Plain("  " + name + " = " + os.Getenv(name))
	}
	a.log.Plain("")
}

func (a *Action) showMappingsLegend() {
	a.log.Info("Mappings Legend:", "")
	a.log.Plain("  " + a.icons.Force + "The source will overwrite the destination")
	a.log.Plain("  " + a.icons.Only + "Filtered by 'only' whitelist")
	a.log.Plain("  " + a.icons.Ignore + "Filtered by 'ignore' blacklist")
	a.log.Plain("  " + a.icons.Hook + "Post-sync hooks configured")
	a.log.Plain("  " + a.icons.Invalid + "Invalid paths detected in the source or destination")
	a.log.Plain("")
}

func (a *Action) showMappings() {
	a.log.Info("Mappings:", "")
	for _, m := range a.mappings {
		flags := a.mappingFlags(m)
		a.log.Plain(fmt.Sprintf("  %s%s → %s", flags, paths.ColorizeEnvVars(m.OriginalSrc()), paths.ColorizeEnvVars(m.OriginalDest())))
	}
	a.log.Plain("")
}

func (a *Action) mappingFlags(m *model.Mapping) string {
	var b strings.Builder
	if m.Force() {
		b.WriteString(a.icons.Force)
	}
	if m.HasInclusions() {
		b.WriteString(a.icons.Only)
	}
	if m.HasIgnores() {
		b.WriteString(a.icons.Ignore)
	}
	if m.HasHooks() {
		b.WriteString(a.icons.Hook)
	}
	if !m.Valid() {
		b.WriteString(a.icons.Invalid)
	}
	return b.String()
}

func (a *Action) showDifferencesLegend() {
	a.log.Info("Differences Legend:", "")
	a.log.Plain("  " + a.icons.DiffCreated + "Created/added file")
	a.log.Plain("  " + a.icons.DiffUpdated + "Updated/modified file")
	a.log.Plain("  " + a.icons.DiffRemoved + "Removed/deleted file")
	a.log.Plain("")
}

func (a *Action) showInvalidPaths() {
	var invalid []*model.Mapping
	for _, m := range a.mappings {
		if !m.Valid() {
			invalid = append(invalid, m)
		}
	}
	if len(invalid) == 0 {
		return
	}
	a.log.Error(fmt.Sprintf("Invalid Paths (%d):", len(invalid)))
	for _, m := range invalid {
		a.log.Plain("  " + m.DecoratedSrc() + " → " + m.DecoratedDest())
		if msg, ok := invalidityMessages[m.InvalidityReason()]; ok {
			a.log.Gray("    " + msg[0] + " · fix: " + msg[1])
		}
	}
	a.log.Plain("")
}

// showSelfReferentialConfig warns when this run would rewrite one of the files
// that produced its own configuration. That is legal and supported, but it has
// a consequence a preview cannot show: the incoming rules were not the rules
// this run was planned with, so they govern nothing until the next run.
func (a *Action) showSelfReferentialConfig() {
	refs := config.SelfReferences(a.mappings, a.cfg.Provenance())
	if len(refs) == 0 {
		return
	}
	a.log.Error(fmt.Sprintf("Config synced by this run (%d):", len(refs)))
	for _, r := range refs {
		a.log.Plain("  " + r.ConfigFile)
		a.log.Gray("    via " + r.Mapping.DecoratedSrc() + " → " + r.Mapping.DecoratedDest())
		if r.Role == config.Overwritten {
			a.log.Gray("    overwritten by this run, which was planned from it — an incoming rule")
			a.log.Gray("    change takes effect on the next run and cannot appear in this preview")
		} else {
			a.log.Gray("    copied out by this run, replacing the copy at the far end — an edit")
			a.log.Gray("    made there is reverted without appearing as a difference")
		}
	}
	// Only suggest `source` to someone who is not already using it; when the
	// sourced file is itself in the payload, the fix is the mapping, not source.
	if a.cfg.Provenance().SourcePath == "" {
		a.log.Gray("    · fix: point " + a.cfg.Path() + " at the repo copy with `source`")
	} else {
		a.log.Gray("    · fix: exclude it from the mapping, or keep it outside the synced tree")
	}
	a.log.Plain("")
}

func (a *Action) showDifferences() {
	a.log.Info("Differences:", "")
	var adds, mods, rems []string
	for _, d := range a.diffs {
		adds = append(adds, d.Additions...)
		mods = append(mods, d.Modifications...)
		rems = append(rems, d.Removals...)
	}
	sort.Strings(adds)
	sort.Strings(mods)
	sort.Strings(rems)
	for _, p := range adds {
		a.log.Log(a.icons.DiffCreated+p, a.colors.Additions, false, "")
	}
	for _, p := range mods {
		a.log.Log(a.icons.DiffUpdated+p, a.colors.Modifications, false, "")
	}
	for _, p := range rems {
		a.log.Log(a.icons.DiffRemoved+p, a.colors.Removals, false, "")
	}
	if !a.hasDifferences() {
		a.log.Plain("  No differences")
	}
	a.log.Plain("")

	if a.dir == config.Pull && a.hasDifferences() {
		a.showOrphanPreview()
	}
}

// hookPreviewCommands returns the templated hook commands this run would fire.
func (a *Action) hookPreviewCommands(force bool) []string {
	var toRun []string
	for i, m := range a.valid {
		if !m.HasHooks() {
			continue
		}
		changed := a.changedFilesForHooks(i, m, force)
		if changed == nil {
			continue
		}
		toRun = append(toRun, hook.NewRunner(m, changed, a.log, a.icons.Hook).Preview()...)
	}
	return toRun
}

func (a *Action) showHooksPreview(force bool) {
	toRun := a.hookPreviewCommands(force)
	if len(toRun) == 0 {
		return
	}
	a.log.Info("Hooks to run:", "")
	for _, cmd := range toRun {
		a.log.Plain("  " + cmd)
	}
	a.log.Plain("")
}

// --- destination creation ---

// ensureDestinations creates the missing destination directories this run is
// allowed to create — every fixable one under --create-dest, or the ones the
// user picks at the prompt — and returns them for the caller to report.
func (a *Action) ensureDestinations() []*model.Mapping {
	var fixable []*model.Mapping
	for _, m := range a.mappings {
		if m.DestCreatable() {
			fixable = append(fixable, m)
		}
	}
	if len(fixable) == 0 {
		return nil
	}
	var toCreate []*model.Mapping
	switch {
	case a.opts.CreateDest:
		toCreate = fixable
	case a.opts.Apply && !a.opts.Yes && !a.opts.NonInteractive:
		toCreate = a.promptDestCreation(fixable)
	}
	for _, m := range toCreate {
		_ = m.CreateDest()
	}
	return toCreate
}

// reportCreatedDestinations prints the classic renderer's created-directories
// section. The cockpit shows the same list as a notice instead.
func (a *Action) reportCreatedDestinations(created []*model.Mapping) {
	if len(created) == 0 {
		return
	}
	a.log.Info(fmt.Sprintf("Created %d destination %s:", len(created), pluralDir(len(created))), "")
	for _, m := range created {
		a.log.Plain("  " + paths.ColorizeEnvVars(m.OriginalDest()))
	}
	a.log.Plain("")
}

func (a *Action) promptDestCreation(fixable []*model.Mapping) []*model.Mapping {
	a.log.Info("Missing destination "+pluralDir(len(fixable))+":", "")
	reader := bufio.NewReader(a.stdin)
	var selected []*model.Mapping
	createAll := false
	for _, m := range fixable {
		if createAll {
			selected = append(selected, m)
			continue
		}
		a.log.Print("  Create " + m.OriginalDest() + "? [y/N/a/q] ")
		line, _ := reader.ReadString('\n')
		switch strings.ToLower(strings.TrimSpace(line)) {
		case "y":
			selected = append(selected, m)
		case "a":
			createAll = true
			selected = append(selected, m)
		case "q":
			a.log.Plain("")
			return selected
		}
	}
	a.log.Plain("")
	return selected
}

// --- confirmation ---

func (a *Action) confirmAction() bool {
	total := 0
	for _, d := range a.diffs {
		total += len(d.Additions) + len(d.Modifications) + len(d.Removals)
	}
	a.log.Plain("")
	a.log.Info(fmt.Sprintf("About to modify %d file(s).", total), "")
	a.log.Print("Continue? [y/N] ")
	line, _ := bufio.NewReader(a.stdin).ReadString('\n')
	return strings.ToLower(strings.TrimSpace(line)) == "y"
}

// --- transfer ---

func (a *Action) transferMappings() {
	for i, m := range a.valid {
		d := a.diffs[i]
		if !d.Any() {
			continue
		}
		removals := make([]string, len(d.RemovalRelPaths))
		for j, rel := range d.RemovalRelPaths {
			removals[j] = filepath.Join(m.Dest(), rel)
		}
		if err := transfer.New(m, removals).Run(); err != nil {
			a.reportTransferError(err)
		}
	}
}

func (a *Action) reportTransferError(err error) {
	var perm *derr.PermissionError
	var disk *derr.DiskFullError
	var sym *derr.SymlinkError
	var conflict *derr.TypeConflictError
	switch {
	case errors.As(err, &perm):
		a.log.Error("Permission denied: " + perm.Error())
		a.log.Info("Try: chmod +w <path> or check file permissions", "")
	case errors.As(err, &disk):
		a.log.Error("Disk full: " + disk.Error())
		a.log.Info("Free up disk space and try again", "")
	case errors.As(err, &sym):
		a.log.Error("Symlink error: " + sym.Error())
		a.log.Info("Check that symlink target exists and is accessible", "")
	case errors.As(err, &conflict):
		a.log.Error("Type conflict: " + conflict.Error())
		a.log.Info("Cannot overwrite directory with file or vice versa", "")
	default:
		a.log.Error("File transfer failed: " + err.Error())
	}
}

// --- pull: backups ---

func (a *Action) createBackup() bool {
	if len(a.valid) == 0 {
		return false
	}
	root := a.backupRoot()
	if err := os.MkdirAll(root, 0o755); err != nil {
		return false
	}
	for _, m := range a.valid {
		if !m.BackupPossible() {
			continue
		}
		base, _ := m.BackupBasename()
		backupPath := filepath.Join(root, base)
		if fsutil.IsFile(m.Src()) {
			_ = copyFile(m.Dest(), backupPath)
		} else {
			bm := model.New(model.Attributes{
				Src:    m.Dest(),
				Dest:   backupPath,
				Only:   m.OriginalOnly(),
				Ignore: m.OriginalIgnores(),
				Force:  false,
			})
			_ = transfer.New(bm, nil).Run()
		}
	}
	return true
}

func (a *Action) backupRoot() string {
	if a.backupRootPath == "" {
		a.backupRootPath = filepath.Join(a.cfg.BackupsRoot(), time.Now().Format("20060102150405"))
	}
	return a.backupRootPath
}

func (a *Action) showBackup() {
	a.log.Action("Backup created:", "")
	a.log.Plain("  " + a.backupRoot())
}

func (a *Action) purgeOldBackups() {
	entries, err := filepath.Glob(filepath.Join(a.cfg.BackupsRoot(), "*"))
	if err != nil {
		return
	}
	sort.Sort(sort.Reverse(sort.StringSlice(entries)))
	if len(entries) > 10 {
		a.log.Action("Oldest backup deleted:", "")
		for _, p := range entries[10:] {
			_ = os.RemoveAll(p)
			a.log.Plain("  " + p)
		}
	}
}

// --- pull: orphan cleanup ---

func (a *Action) cleanupOrphans() {
	for _, m := range a.valid {
		if !(m.HasInclusions() && !m.Force() && m.ManifestKey() != "") {
			continue
		}
		current := a.destFilesMatchingInclusions(m)
		man := manifest.New(m.Dest(), m.ManifestKey(), a.cfg.ManifestsRoot())
		for _, orphan := range man.Orphans(current) {
			if !fsutil.Exists(orphan) {
				continue
			}
			_ = os.Remove(orphan)
			a.log.Log(a.icons.DiffRemoved+orphan, a.colors.Removals, false, "")
		}
		_ = man.Write(current)
	}
}

// orphanEntry is a destination file a pull would delete, paired with the
// mapping whose inclusions no longer match it.
type orphanEntry struct {
	path    string
	mapping *model.Mapping
}

// orphans returns the destination files a pull would delete: files a previous
// pull recorded in the manifest that the current inclusions no longer match.
func (a *Action) orphans() []orphanEntry {
	var out []orphanEntry
	for _, m := range a.valid {
		if !(m.HasInclusions() && !m.Force() && m.ManifestKey() != "") {
			continue
		}
		current := a.destFilesMatchingInclusions(m)
		man := manifest.New(m.Dest(), m.ManifestKey(), a.cfg.ManifestsRoot())
		for _, o := range man.Orphans(current) {
			if fsutil.Exists(o) {
				out = append(out, orphanEntry{path: o, mapping: m})
			}
		}
	}
	return out
}

func (a *Action) showOrphanPreview() {
	var orphans []string
	for _, o := range a.orphans() {
		orphans = append(orphans, o.path)
	}
	if len(orphans) == 0 {
		return
	}
	a.log.Info("Orphans to remove:", "")
	sort.Strings(orphans)
	for _, p := range orphans {
		a.log.Log(a.icons.DiffRemoved+p, a.colors.Removals, false, "")
	}
	a.log.Plain("")
}

// --- hooks ---

func (a *Action) executeHooks(force bool) {
	for i, m := range a.valid {
		if !m.HasHooks() {
			continue
		}
		changed := a.changedFilesForHooks(i, m, force)
		if changed == nil {
			continue
		}
		hook.NewRunner(m, changed, a.log, a.icons.Hook).Execute()
	}
}

// changedFilesForHooks returns the files a hook should act on: additions +
// modifications, or (in force mode, when there are none) all destination files.
// Returns nil when there is nothing to run.
func (a *Action) changedFilesForHooks(idx int, m *model.Mapping, force bool) []string {
	d := a.diffs[idx]
	changed := append(append([]string(nil), d.Additions...), d.Modifications...)
	if len(changed) == 0 {
		if !force {
			return nil
		}
		changed = allDestFiles(m)
		if len(changed) == 0 {
			return nil
		}
	}
	return changed
}

// --- helpers ---

func (a *Action) mappingsEnvVars() []string {
	seen := make(map[string]bool)
	var out []string
	for _, m := range a.mappings {
		for _, p := range []string{m.OriginalSrc(), m.OriginalDest()} {
			for _, name := range paths.ExtractEnvVars(p) {
				if !seen[name] {
					seen[name] = true
					out = append(out, name)
				}
			}
		}
	}
	return out
}

func (a *Action) destFilesMatchingInclusions(m *model.Mapping) []string {
	dest := m.Dest()
	if !fsutil.IsDir(dest) {
		return nil
	}
	var files []string
	_ = filepath.WalkDir(dest, func(path string, d fs.DirEntry, err error) error {
		if err != nil || path == dest || d.IsDir() {
			return nil
		}
		if m.Include(path) {
			if rel, e := filepath.Rel(dest, path); e == nil {
				files = append(files, rel)
			}
		}
		return nil
	})
	return files
}

func allDestFiles(m *model.Mapping) []string {
	dest := m.Dest()
	if fsutil.IsDir(dest) {
		var files []string
		_ = filepath.WalkDir(dest, func(path string, d fs.DirEntry, err error) error {
			if err != nil || d.IsDir() {
				return nil
			}
			files = append(files, path)
			return nil
		})
		return files
	}
	if fsutil.IsFile(dest) {
		return []string{dest}
	}
	return nil
}

func copyFile(src, dst string) error {
	info, err := os.Stat(src)
	if err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, info.Mode().Perm())
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

func pluralDir(n int) string {
	if n == 1 {
		return "directory"
	}
	return "directories"
}

type sections struct {
	options           bool
	envVars           bool
	mappingsLegend    bool
	mappings          bool
	differencesLegend bool
	differences       bool
	diffContent       bool
	invalidPaths      bool
	selfRefConfig     bool
}

func computeSections(o Options) sections {
	showAll := o.Verbose
	return sections{
		options:           showAll || o.ShowOptions || o.OnlyConfig,
		envVars:           showAll || o.ShowEnv,
		mappingsLegend:    showAll || o.Legend,
		mappings:          showAll || o.ShowMappings || o.OnlyMappings || o.OnlyConfig,
		differencesLegend: showAll || o.Legend,
		differences:       !(o.Quiet || o.OnlyMappings || o.OnlyConfig),
		diffContent:       o.DiffContent,
		invalidPaths:      true,
		// Always on, like invalidPaths: a run that rewrites its own governing
		// config is worth saying out loud even when every other section is off.
		selfRefConfig: true,
	}
}
