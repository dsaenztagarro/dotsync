// Package fsutil holds filesystem helpers shared by the model and the diff
// engine. The comparison strategy mirrors the Ruby implementation's
// size-first, content-second optimization.
package fsutil

import (
	"bytes"
	"io"
	"os"
)

const compareChunkSize = 64 * 1024

// FilesDiffer reports whether two regular files have different contents. It
// compares sizes first (a single stat each) and only reads bytes when the
// sizes match, mirroring DirectoryDiffer#files_differ? and Mapping#file_changed?
// (File.size check, then FileUtils.compare_file).
func FilesDiffer(a, b string) (bool, error) {
	sa, err := os.Stat(a)
	if err != nil {
		return false, err
	}
	sb, err := os.Stat(b)
	if err != nil {
		return false, err
	}
	if sa.Size() != sb.Size() {
		return true, nil
	}
	return contentDiffers(a, b)
}

func contentDiffers(a, b string) (bool, error) {
	fa, err := os.Open(a)
	if err != nil {
		return false, err
	}
	defer fa.Close()
	fb, err := os.Open(b)
	if err != nil {
		return false, err
	}
	defer fb.Close()

	bufA := make([]byte, compareChunkSize)
	bufB := make([]byte, compareChunkSize)
	for {
		nA, errA := io.ReadFull(fa, bufA)
		nB, errB := io.ReadFull(fb, bufB)
		if nA != nB || !bytes.Equal(bufA[:nA], bufB[:nB]) {
			return true, nil
		}
		if errA == io.EOF || errA == io.ErrUnexpectedEOF {
			// Sizes were equal, so both streams end together.
			return false, nil
		}
		if errA != nil && errA != io.ErrUnexpectedEOF {
			return false, errA
		}
		if errB != nil && errB != io.ErrUnexpectedEOF {
			return false, errB
		}
	}
}
