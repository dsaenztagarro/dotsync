package model

import "strings"

// fnmatch reports whether name matches the shell glob pattern, reproducing
// Ruby's File.fnmatch with the DEFAULT flags (0). The consequences that matter
// for dotsync:
//
//   - No FNM_PATHNAME: `*` and `?` match `/` like any other character.
//   - Backslash escapes the next character (FNM_NOESCAPE is off).
//   - `[...]` character classes support ranges and `!`/`^` negation.
//
// The leading-period rule (FNM_DOTMATCH off) is intentionally NOT modeled:
// dotsync only ever matches inclusion patterns that have been joined onto an
// absolute src/dest, so both pattern and name always begin with `/` and a
// leading `.` never occurs at position 0 of the string. Go's stdlib
// path.Match cannot be used here because it implements FNM_PATHNAME semantics.
func fnmatch(pattern, name string) bool {
	var px, nx int
	// Backtracking state for the most recent `*`.
	backtrackPx, backtrackNx := -1, -1

	for px < len(pattern) || nx < len(name) {
		if px < len(pattern) {
			switch c := pattern[px]; c {
			case '*':
				// Match zero characters now; on failure, resume here having
				// consumed one more character of name.
				backtrackPx = px
				backtrackNx = nx + 1
				px++
				continue
			case '?':
				if nx < len(name) {
					px++
					nx++
					continue
				}
			case '[':
				if nx < len(name) {
					if matched, after, ok := matchBracket(pattern, px, name[nx]); ok {
						if matched {
							px = after
							nx++
							continue
						}
						// Well-formed class that did not match: fall through to
						// backtracking.
						break
					}
					// Malformed class: treat '[' as a literal character.
					if name[nx] == '[' {
						px++
						nx++
						continue
					}
				}
			case '\\':
				if px+1 < len(pattern) {
					if nx < len(name) && pattern[px+1] == name[nx] {
						px += 2
						nx++
						continue
					}
				} else if nx < len(name) && name[nx] == '\\' {
					// Trailing backslash: literal backslash.
					px++
					nx++
					continue
				}
			default:
				if nx < len(name) && name[nx] == c {
					px++
					nx++
					continue
				}
			}
		}
		// Mismatch, or pattern exhausted with name remaining: backtrack to the
		// last `*` and let it swallow one more character.
		if backtrackNx > 0 && backtrackNx <= len(name) {
			px = backtrackPx
			nx = backtrackNx
			continue
		}
		return false
	}
	return true
}

// matchBracket evaluates a `[...]` character class beginning at pattern[start]
// (which must be '['). It reports whether ch is a member, the index just past
// the closing ']', and whether the class was well-formed. When ok is false the
// class is malformed (no closing ']') and the caller should treat '[' as a
// literal character, as Ruby's fnmatch does.
func matchBracket(pattern string, start int, ch byte) (matched bool, after int, ok bool) {
	i := start + 1
	negate := false
	if i < len(pattern) && (pattern[i] == '!' || pattern[i] == '^') {
		negate = true
		i++
	}

	member := false
	first := true
	for i < len(pattern) {
		c := pattern[i]
		if c == ']' && !first {
			return member != negate, i + 1, true
		}
		first = false

		// Range: c '-' hi, where the character after '-' is not the closing ']'.
		if i+2 < len(pattern) && pattern[i+1] == '-' && pattern[i+2] != ']' {
			if lo, hi := c, pattern[i+2]; lo <= ch && ch <= hi {
				member = true
			}
			i += 3
			continue
		}
		if c == ch {
			member = true
		}
		i++
	}
	// No closing ']': malformed.
	return false, 0, false
}

// hasGlobMeta reports whether s contains any glob metacharacter, mirroring
// Ruby's glob_pattern? => path.match?(/[*?\[]/).
func hasGlobMeta(s string) bool {
	return strings.ContainsAny(s, "*?[")
}
