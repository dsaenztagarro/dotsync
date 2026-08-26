// Package paths reproduces the path-handling semantics of the Ruby
// dotsync's Dotsync::PathUtils module. Parity with the Ruby behavior is
// intentional and load-bearing: mappings, filters, and the diff engine all
// depend on these transformations producing byte-identical results.
package paths

import (
	"os"
	"os/user"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

// EnvVarsColor is the 256-color index used to highlight $VAR segments in
// mapping display. Mirrors Dotsync::PathUtils::ENV_VARS_COLOR.
const EnvVarsColor = 104

// envVarPattern matches a `$` followed by one or more word characters
// ([A-Za-z0-9_]). It deliberately does NOT match the `${VAR}` form, matching
// the Ruby regexp /\$(\w+)/.
var envVarPattern = regexp.MustCompile(`\$(\w+)`)

// ExpandEnvVars replaces each `$NAME` occurrence with the value of the
// environment variable NAME. Unset variables expand to the empty string,
// matching Ruby's `path.gsub(/\$(\w+)/) { ENV[$1] }` (a nil replacement
// becomes "").
func ExpandEnvVars(path string) string {
	return envVarPattern.ReplaceAllStringFunc(path, func(match string) string {
		return os.Getenv(match[1:]) // strip the leading '$'
	})
}

// ExtractEnvVars returns the names of every `$NAME` occurrence, in order and
// including duplicates. Mirrors `path.scan(/\$(\w+)/).flatten`.
func ExtractEnvVars(path string) []string {
	matches := envVarPattern.FindAllStringSubmatch(path, -1)
	names := make([]string, 0, len(matches))
	for _, m := range matches {
		names = append(names, m[1])
	}
	return names
}

// ColorizeEnvVars wraps each `$NAME` segment in a 256-color ANSI escape,
// leaving the rest of the path untouched. Mirrors the Ruby colorize_env_vars.
func ColorizeEnvVars(path string) string {
	return envVarPattern.ReplaceAllStringFunc(path, func(match string) string {
		return "\x1b[38;5;104m" + match + "\x1b[0m"
	})
}

// EnvVarSpans returns the [start, end) byte ranges of every `$NAME` segment in
// path. It exists for renderers that highlight those segments themselves
// (the TUI styles them with lipgloss) instead of embedding the escapes
// ColorizeEnvVars writes, so both share one definition of what a variable is.
func EnvVarSpans(path string) [][]int {
	return envVarPattern.FindAllStringIndex(path, -1)
}

// RelativeToAbsolute joins each relative path onto base. Mirrors
// `paths.map { |p| File.join(base, p) }`.
func RelativeToAbsolute(rels []string, base string) []string {
	abs := make([]string, len(rels))
	for i, rel := range rels {
		abs[i] = filepath.Join(base, rel)
	}
	return abs
}

// PathIsParentOrSame reports whether parent equals child or is an ancestor of
// child, after expanding both to absolute paths. Mirrors
// path_is_parent_or_same? which expands via Pathname#expand_path (no /tmp
// translation) and walks child.ascend looking for parent.
func PathIsParentOrSame(parent, child string) bool {
	p := expandPath(parent)
	c := expandPath(child)
	if p == c {
		return true
	}
	return strings.HasPrefix(c, ensureTrailingSep(p))
}

// TranslateTmpPath rewrites a leading "/tmp" to "/private/tmp" on macOS only,
// leaving every other path unchanged. Mirrors translate_tmp_path exactly,
// including its use of String#start_with?/#sub (first occurrence): a path such
// as "/tmpfoo" also starts with "/tmp" and is rewritten to "/private/tmpfoo".
func TranslateTmpPath(path string) string {
	if runtime.GOOS == "darwin" && strings.HasPrefix(path, "/tmp") {
		return strings.Replace(path, "/tmp", "/private/tmp", 1)
	}
	return path
}

// SanitizePath expands environment variables, expands the path to an absolute
// form (resolving ~ and CWD-relative paths, cleaning . and ..), then applies
// the macOS /tmp translation. Mirrors
// sanitize_path = translate_tmp_path(File.expand_path(expand_env_vars(path))).
func SanitizePath(path string) string {
	return TranslateTmpPath(expandPath(ExpandEnvVars(path)))
}

// ensureTrailingSep appends a path separator if one is not already present, so
// prefix checks respect path-component boundaries.
func ensureTrailingSep(p string) string {
	if strings.HasSuffix(p, string(filepath.Separator)) {
		return p
	}
	return p + string(filepath.Separator)
}

// ExpandPath is the exported form of Ruby's File.expand_path: it expands a
// leading ~/~user and resolves CWD-relative paths to a cleaned absolute path,
// WITHOUT environment-variable or /tmp translation. Used for XDG base-directory
// resolution, which mirrors `File.expand_path(ENV[...] || "~/...")`.
func ExpandPath(p string) string { return expandPath(p) }

// expandPath reproduces Ruby's File.expand_path: it expands a leading ~ or
// ~user to the corresponding home directory, resolves CWD-relative paths to
// absolute, and cleans the result (collapsing ., .., and duplicate
// separators). It does NOT resolve symlinks (that would be File.realpath).
func expandPath(p string) string {
	p = expandTilde(p)
	if !filepath.IsAbs(p) {
		if abs, err := filepath.Abs(p); err == nil {
			return abs // filepath.Abs already cleans
		}
	}
	return filepath.Clean(p)
}

// expandTilde handles the ~ and ~user prefixes the way File.expand_path does.
func expandTilde(p string) string {
	if p == "~" {
		if home, err := os.UserHomeDir(); err == nil {
			return home
		}
		return p
	}
	if strings.HasPrefix(p, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, p[2:])
		}
		return p
	}
	if strings.HasPrefix(p, "~") {
		rest := p[1:]
		name, tail, _ := strings.Cut(rest, "/")
		if u, err := user.Lookup(name); err == nil {
			if tail == "" {
				return u.HomeDir
			}
			return filepath.Join(u.HomeDir, tail)
		}
	}
	return p
}
