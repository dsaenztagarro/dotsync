package fsutil

import "os"

// Exists reports whether a path exists, following symlinks (Ruby File.exist?).
func Exists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

// IsFile reports whether a path is a regular file, following symlinks
// (Ruby File.file?).
func IsFile(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.Mode().IsRegular()
}

// IsDir reports whether a path is a directory, following symlinks
// (Ruby File.directory?).
func IsDir(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.IsDir()
}
