// Package derr defines dotsync's typed errors, mirroring the Ruby class
// hierarchy in lib/dotsync/errors.rb. In Ruby, PermissionError, DiskFullError,
// SymlinkError, and TypeConflictError all descend from FileTransferError so a
// single rescue can catch the family; here each is a distinct type and callers
// use errors.As, while TransferError() reports family membership.
package derr

// PermissionError maps EACCES/EPERM during a transfer.
type PermissionError struct {
	Msg string
	Err error
}

func (e *PermissionError) Error() string  { return e.Msg }
func (e *PermissionError) Unwrap() error  { return e.Err }
func (e *PermissionError) transferError() {}

// DiskFullError maps ENOSPC during a transfer.
type DiskFullError struct {
	Msg string
	Err error
}

func (e *DiskFullError) Error() string  { return e.Msg }
func (e *DiskFullError) Unwrap() error  { return e.Err }
func (e *DiskFullError) transferError() {}

// SymlinkError maps a failure creating a symlink.
type SymlinkError struct {
	Msg string
	Err error
}

func (e *SymlinkError) Error() string  { return e.Msg }
func (e *SymlinkError) Unwrap() error  { return e.Err }
func (e *SymlinkError) transferError() {}

// TypeConflictError maps an attempt to overwrite a directory with a file or
// symlink (or vice versa).
type TypeConflictError struct {
	Msg string
}

func (e *TypeConflictError) Error() string  { return e.Msg }
func (e *TypeConflictError) transferError() {}

// FileTransferError is the generic transfer failure (Ruby's FileTransferError
// base, used directly for uncategorized failures).
type FileTransferError struct {
	Msg string
	Err error
}

func (e *FileTransferError) Error() string  { return e.Msg }
func (e *FileTransferError) Unwrap() error  { return e.Err }
func (e *FileTransferError) transferError() {}

// ConfigError mirrors Ruby's ConfigError.
type ConfigError struct {
	Msg string
	Err error
}

func (e *ConfigError) Error() string { return e.Msg }
func (e *ConfigError) Unwrap() error { return e.Err }

// HookError mirrors Ruby's HookError.
type HookError struct {
	Msg string
	Err error
}

func (e *HookError) Error() string { return e.Msg }
func (e *HookError) Unwrap() error { return e.Err }

// transferErrorMarker is implemented by every error in the FileTransferError
// family.
type transferErrorMarker interface{ transferError() }

// IsTransferError reports whether err (or anything it wraps) belongs to the
// FileTransferError family — the Go analog of `rescue FileTransferError`.
func IsTransferError(err error) bool {
	for err != nil {
		if _, ok := err.(transferErrorMarker); ok {
			return true
		}
		u, ok := err.(interface{ Unwrap() error })
		if !ok {
			return false
		}
		err = u.Unwrap()
	}
	return false
}
