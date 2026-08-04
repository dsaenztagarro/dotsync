package model

import "testing"

func TestFnmatch(t *testing.T) {
	tests := []struct {
		pattern string
		name    string
		want    bool
	}{
		// Literals.
		{"abc", "abc", true},
		{"abc", "abd", false},
		{"", "", true},
		{"", "a", false},

		// `*` matches any run, including dots and slashes (no FNM_PATHNAME).
		{"local.*.plist", "local.brew.upgrade.plist", true},
		{"local.*.plist", "local..plist", true},
		{"local.*.plist", "com.apple.something.plist", false},
		{"a*z", "a/b/c/z", true},
		{"*", "anything/with/slashes", true},
		{"/src/*", "/src/.hidden", true}, // no leading-dot protection mid-string

		// `?` matches exactly one character (also `/`).
		{"config.?", "config.a", true},
		{"config.?", "config.ab", false},
		{"a?b", "a/b", true},

		// Character classes.
		{"log.[0-9]", "log.1", true},
		{"log.[0-9]", "log.a", false},
		{"x[abc]y", "xby", true},
		{"x[abc]y", "xdy", false},
		{"x[!0-9]y", "xay", true},
		{"x[!0-9]y", "x5y", false},
		{"x[^0-9]y", "xay", true},
		{"file[.]txt", "file.txt", true},

		// Escaping (FNM_NOESCAPE off): backslash escapes the metachar.
		{`a\*b`, "a*b", true},
		{`a\*b`, "axb", false},
		{`a\?b`, "a?b", true},

		// Malformed class: '[' treated literally.
		{"a[bc", "a[bc", true},
		{"a[b", "axb", false},
	}
	for _, tt := range tests {
		t.Run(tt.pattern+"__"+tt.name, func(t *testing.T) {
			if got := fnmatch(tt.pattern, tt.name); got != tt.want {
				t.Errorf("fnmatch(%q, %q) = %v, want %v", tt.pattern, tt.name, got, tt.want)
			}
		})
	}
}

func TestHasGlobMeta(t *testing.T) {
	for _, s := range []string{"a*b", "a?b", "a[b", "*", "?", "["} {
		if !hasGlobMeta(s) {
			t.Errorf("hasGlobMeta(%q) = false, want true", s)
		}
	}
	for _, s := range []string{"abc", "a.b.c", "/path/to/file", "a-b_c"} {
		if hasGlobMeta(s) {
			t.Errorf("hasGlobMeta(%q) = true, want false", s)
		}
	}
}
