# frozen_string_literal: true

module Dotsync
  class Error < StandardError; end
  class ConfigError < StandardError; end
  class FileTransferError < Error; end
  class PermissionError < FileTransferError; end
  class DiskFullError < FileTransferError; end
  class SymlinkError < FileTransferError; end
  class TypeConflictError < FileTransferError; end
  class HookError < Error; end
end
