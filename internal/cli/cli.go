// Package cli wires the cobra command tree onto the action layer. It preserves
// the Ruby CLI's command set (push, pull, watch, setup/init, status, diff) and
// flag surface, including the deprecated no-op flags and the exit-code contract
// (a returned error becomes a non-zero exit in main).
package cli

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/dsaenztagarro/dotsync/internal/action"
	"github.com/dsaenztagarro/dotsync/internal/config"
	"github.com/dsaenztagarro/dotsync/internal/render"
)

// version is the binary version, overridable at build time via -ldflags.
var version = "0.0.0-dev"

type flags struct {
	config       string
	apply        bool
	dryRun       bool
	yes          bool
	quiet        bool
	verbose      bool
	createDest   bool
	forceHooks   bool
	legend       bool
	showMappings bool
	showEnv      bool
	showOptions  bool
	onlyDiff     bool
	onlyConfig   bool
	onlyMappings bool
	diffContent  bool
	trace        bool
}

// Execute builds and runs the root command, returning any error for main to
// translate into an exit code.
func Execute() error {
	root := &cobra.Command{
		Use:           "dotsync",
		Short:         "Manage and synchronize your dotfiles across machines",
		Version:       version,
		SilenceUsage:  true,
		SilenceErrors: true,
	}

	root.AddCommand(
		syncCommand("pull", "Sync remote -> local (preview by default)", config.Pull, nil),
		syncCommand("push", "Sync local -> remote (preview by default)", config.Push, nil),
		syncCommand("diff", "Preview local -> remote changes without applying", config.Push, func(o *action.Options) {
			o.Apply = false
		}),
		syncCommand("status", "Show config and mappings without diffing", config.Push, func(o *action.Options) {
			o.Apply = false
			o.OnlyConfig = true
			o.OnlyMappings = true
		}),
		watchCommand(),
		setupCommand(),
	)
	return root.Execute()
}

func syncCommand(use, short string, dir config.Direction, preset func(*action.Options)) *cobra.Command {
	f := &flags{}
	cmd := &cobra.Command{
		Use:   use,
		Short: short,
		Args:  cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			return run(dir, f, preset)
		},
	}
	addCommonFlags(cmd, f)
	return cmd
}

func addCommonFlags(cmd *cobra.Command, f *flags) {
	fl := cmd.Flags()
	fl.StringVarP(&f.config, "config", "c", "", "path to the config file")
	fl.BoolVarP(&f.apply, "apply", "a", false, "apply changes (default is a dry-run preview)")
	fl.BoolVar(&f.dryRun, "dry-run", false, "preview changes without applying (default)")
	fl.BoolVarP(&f.yes, "yes", "y", false, "skip the confirmation prompt")
	fl.BoolVarP(&f.quiet, "quiet", "q", false, "suppress the differences section")
	fl.BoolVarP(&f.verbose, "verbose", "v", false, "show all output sections")
	fl.BoolVar(&f.createDest, "create-dest", false, "create missing destination directories")
	fl.BoolVar(&f.forceHooks, "force-hooks", false, "run hooks even when nothing changed")
	fl.BoolVar(&f.legend, "legend", false, "show the mappings and differences legends")
	fl.BoolVar(&f.showMappings, "show-mappings", false, "show the mappings table")
	fl.BoolVar(&f.showEnv, "show-env", false, "show referenced environment variables")
	fl.BoolVar(&f.showOptions, "show-options", false, "show the resolved options")
	fl.BoolVar(&f.onlyDiff, "only-diff", false, "show only the differences section")
	fl.BoolVar(&f.onlyConfig, "only-config", false, "show only config/options")
	fl.BoolVar(&f.onlyMappings, "only-mappings", false, "show only the mappings table")
	fl.BoolVar(&f.diffContent, "diff-content", false, "show unified content diffs for modified files")
	fl.BoolVar(&f.trace, "trace", false, "print full error traces")

	// Deprecated no-op flags, accepted silently for backward compatibility.
	for _, name := range []string{"no-legend", "no-config", "no-mappings", "no-diff-legend", "no-diff"} {
		var noop bool
		fl.BoolVar(&noop, name, false, "")
		_ = fl.MarkHidden(name)
	}
}

func run(dir config.Direction, f *flags, preset func(*action.Options)) error {
	cfgPath := f.config
	if cfgPath == "" {
		cfgPath = config.DefaultConfigPath()
	}
	cfg, err := config.Load(cfgPath, dir)
	if err != nil {
		return err
	}
	raw := cfg.Raw()
	log := render.NewLogger(os.Stdout, render.ColorEnabled(os.Stdout))
	opts := action.Options{
		Apply:        f.apply && !f.dryRun,
		Yes:          f.yes,
		Quiet:        f.quiet,
		Verbose:      f.verbose,
		CreateDest:   f.createDest,
		ForceHooks:   f.forceHooks,
		Legend:       f.legend,
		ShowMappings: f.showMappings,
		ShowEnv:      f.showEnv,
		ShowOptions:  f.showOptions,
		OnlyDiff:     f.onlyDiff,
		OnlyConfig:   f.onlyConfig,
		OnlyMappings: f.onlyMappings,
		DiffContent:  f.diffContent,
	}
	if preset != nil {
		preset(&opts)
	}
	a := action.New(cfg, dir, log, render.LoadColors(raw), render.LoadIcons(raw), opts, os.Stdin)
	return a.Execute()
}

func watchCommand() *cobra.Command {
	f := &flags{}
	cmd := &cobra.Command{
		Use:   "watch",
		Short: "Watch sources and sync changes live (Ctrl+C to exit)",
		Args:  cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			cfgPath := f.config
			if cfgPath == "" {
				cfgPath = config.DefaultConfigPath()
			}
			cfg, err := config.LoadWatch(cfgPath)
			if err != nil {
				return err
			}
			raw := cfg.Raw()
			log := render.NewLogger(os.Stdout, render.ColorEnabled(os.Stdout))
			opts := action.Options{
				Quiet:        f.quiet,
				Verbose:      f.verbose,
				CreateDest:   f.createDest,
				Legend:       f.legend,
				ShowMappings: f.showMappings,
				ShowEnv:      f.showEnv,
				ShowOptions:  f.showOptions,
			}
			a := action.New(cfg, config.Push, log, render.LoadColors(raw), render.LoadIcons(raw), opts, os.Stdin)
			return a.Watch()
		},
	}
	addCommonFlags(cmd, f)
	return cmd
}

func setupCommand() *cobra.Command {
	var configPath string
	cmd := &cobra.Command{
		Use:     "setup",
		Aliases: []string{"init"},
		Short:   "Write a starter configuration file",
		Args:    cobra.NoArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			path := configPath
			if path == "" {
				path = config.DefaultConfigPath()
			}
			written, err := config.WriteDefault(path)
			if err != nil {
				return err
			}
			fmt.Println("Wrote starter dotsync config to " + written)
			return nil
		},
	}
	cmd.Flags().StringVarP(&configPath, "config", "c", "", "path to the config file")
	return cmd
}

// SetVersion lets main inject the build version.
func SetVersion(v string) {
	if v != "" {
		version = v
	}
}

// Fail prints an error to stderr; used by main for a uniform exit path.
func Fail(err error) {
	fmt.Fprintln(os.Stderr, err.Error())
}
