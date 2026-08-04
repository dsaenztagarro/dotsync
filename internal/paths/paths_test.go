package paths

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestExpandEnvVars(t *testing.T) {
	t.Setenv("TEST_VAR", "/test/path")
	t.Setenv("HOME_VAR", "/home/user")
	os.Unsetenv("UNDEFINED_VAR")

	tests := []struct {
		name string
		in   string
		want string
	}{
		{"single variable", "$TEST_VAR/file.txt", "/test/path/file.txt"},
		{"multiple variables", "$HOME_VAR/$TEST_VAR/file.txt", "/home/user//test/path/file.txt"},
		{"no variables", "/regular/path/file.txt", "/regular/path/file.txt"},
		{"undefined variable removed", "$UNDEFINED_VAR/file.txt", "/file.txt"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := ExpandEnvVars(tt.in); got != tt.want {
				t.Errorf("ExpandEnvVars(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}

func TestExtractEnvVars(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want []string
	}{
		{"single", "$HOME/file.txt", []string{"HOME"}},
		{"multiple", "$HOME/$USER/file.txt", []string{"HOME", "USER"}},
		{"none", "/regular/path/file.txt", []string{}},
		{"duplicates kept separately", "$HOME/$HOME/file.txt", []string{"HOME", "HOME"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ExtractEnvVars(tt.in)
			if !equalStrings(got, tt.want) {
				t.Errorf("ExtractEnvVars(%q) = %v, want %v", tt.in, got, tt.want)
			}
		})
	}
}

func TestColorizeEnvVars(t *testing.T) {
	t.Run("single", func(t *testing.T) {
		got := ColorizeEnvVars("$HOME/file.txt")
		if !strings.Contains(got, "\x1b[38;5;104m$HOME\x1b[0m") {
			t.Errorf("missing colorized $HOME in %q", got)
		}
		if !strings.HasSuffix(got, "/file.txt") {
			t.Errorf("path tail altered: %q", got)
		}
	})
	t.Run("multiple", func(t *testing.T) {
		got := ColorizeEnvVars("$HOME/$USER/file.txt")
		if !strings.Contains(got, "\x1b[38;5;104m$HOME\x1b[0m") ||
			!strings.Contains(got, "\x1b[38;5;104m$USER\x1b[0m") {
			t.Errorf("missing colorized segments in %q", got)
		}
	})
	t.Run("none", func(t *testing.T) {
		if got := ColorizeEnvVars("/regular/path/file.txt"); got != "/regular/path/file.txt" {
			t.Errorf("unexpected change: %q", got)
		}
	})
}

func TestRelativeToAbsolute(t *testing.T) {
	tests := []struct {
		name string
		in   []string
		base string
		want []string
	}{
		{"single", []string{"file.txt"}, "/base", []string{"/base/file.txt"}},
		{"multiple", []string{"file1.txt", "dir/file2.txt"}, "/base", []string{"/base/file1.txt", "/base/dir/file2.txt"}},
		{"empty", []string{}, "/base", []string{}},
		{"subdirs", []string{"a/b/c.txt"}, "/base", []string{"/base/a/b/c.txt"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := RelativeToAbsolute(tt.in, tt.base); !equalStrings(got, tt.want) {
				t.Errorf("RelativeToAbsolute(%v, %q) = %v, want %v", tt.in, tt.base, got, tt.want)
			}
		})
	}
}

func TestPathIsParentOrSame(t *testing.T) {
	tests := []struct {
		name          string
		parent, child string
		want          bool
	}{
		{"same path", "/tmp/test", "/tmp/test", true},
		{"parent of child", "/tmp", "/tmp/test/file.txt", true},
		{"not parent", "/tmp/a", "/tmp/b/file.txt", false},
		{"child of second", "/tmp/test/file.txt", "/tmp", false},
		{"sibling prefix not a parent", "/tmp/a", "/tmp/ab", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := PathIsParentOrSame(tt.parent, tt.child); got != tt.want {
				t.Errorf("PathIsParentOrSame(%q, %q) = %v, want %v", tt.parent, tt.child, got, tt.want)
			}
		})
	}
}

func TestTranslateTmpPath(t *testing.T) {
	if runtime.GOOS == "darwin" {
		if got := TranslateTmpPath("/tmp/file.txt"); got != "/private/tmp/file.txt" {
			t.Errorf("darwin: TranslateTmpPath(/tmp/file.txt) = %q", got)
		}
	} else {
		if got := TranslateTmpPath("/tmp/file.txt"); got != "/tmp/file.txt" {
			t.Errorf("non-darwin: TranslateTmpPath(/tmp/file.txt) = %q", got)
		}
	}
	if got := TranslateTmpPath("/home/user/file.txt"); got != "/home/user/file.txt" {
		t.Errorf("non-/tmp path altered: %q", got)
	}
	if got := TranslateTmpPath("/home/tmp/file.txt"); got != "/home/tmp/file.txt" {
		t.Errorf("mid-path /tmp altered: %q", got)
	}
}

func TestSanitizePath(t *testing.T) {
	t.Setenv("TEST_HOME", "/home/test")

	t.Run("expands env and absolute", func(t *testing.T) {
		want := "/home/test/file.txt"
		if runtime.GOOS == "darwin" {
			// /home is not under /tmp, so no translation.
		}
		if got := SanitizePath("$TEST_HOME/file.txt"); got != want {
			t.Errorf("SanitizePath = %q, want %q", got, want)
		}
	})

	t.Run("expands relative path", func(t *testing.T) {
		got := SanitizePath("./file.txt")
		if !strings.HasPrefix(got, "/") || !strings.HasSuffix(got, "file.txt") {
			t.Errorf("SanitizePath(./file.txt) = %q", got)
		}
	})

	t.Run("collapses double slashes and dot segments", func(t *testing.T) {
		if got := SanitizePath("/a//b/../c"); got != "/a/c" {
			t.Errorf("SanitizePath(/a//b/../c) = %q, want /a/c", got)
		}
	})

	if runtime.GOOS == "darwin" {
		t.Run("darwin tmp translation", func(t *testing.T) {
			if got := SanitizePath("/tmp/file.txt"); got != "/private/tmp/file.txt" {
				t.Errorf("SanitizePath(/tmp/file.txt) = %q", got)
			}
		})
	}
}

func TestExpandTilde(t *testing.T) {
	home, err := os.UserHomeDir()
	if err != nil {
		t.Skip("no home dir")
	}
	if got := expandTilde("~"); got != home {
		t.Errorf("expandTilde(~) = %q, want %q", got, home)
	}
	if got := expandTilde("~/foo"); got != filepath.Join(home, "foo") {
		t.Errorf("expandTilde(~/foo) = %q, want %q", got, filepath.Join(home, "foo"))
	}
	if got := expandTilde("/no/tilde"); got != "/no/tilde" {
		t.Errorf("expandTilde(/no/tilde) = %q", got)
	}
}

func equalStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
