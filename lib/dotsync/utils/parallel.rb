# frozen_string_literal: true

module Dotsync
  # Thread-based parallel execution for independent operations.
  #
  # == Why Parallelization?
  #
  # Dotsync processes multiple independent mappings (e.g., nvim, alacritty, zsh configs).
  # Each mapping's diff computation and file transfer is independent of others.
  # By processing mappings in parallel, we utilize multiple CPU cores and overlap I/O waits.
  #
  # == Implementation Details
  #
  # Uses Ruby's native Thread class with a work-stealing queue pattern:
  # - Pre-sized results array for thread-safe index assignment (no mutex needed for writes)
  # - Queue-based work distribution for automatic load balancing
  # - Errors collected and re-raised after all threads complete
  #
  # == When It Helps
  #
  # Parallelization provides the most benefit when:
  # - Processing many mappings (5+ independent directories)
  # - Mappings have similar sizes (good load distribution)
  # - I/O-bound operations (file reads/writes overlap)
  #
  # For small mapping counts or CPU-bound work, the thread overhead may negate benefits.
  #
  module Parallel
    # Default number of threads (matches typical CPU core count)
    DEFAULT_THREADS = 4

    # Executes a block for each item in the collection using parallel threads.
    # Returns results in the same order as the input collection.
    #
    # @param items [Array] Collection of items to process
    # @param threads [Integer] Number of parallel threads (default: 4)
    # @yield [item] Block to execute for each item
    # @return [Array] Results in same order as input
    #
    # @example
    #   results = Dotsync::Parallel.map(urls, threads: 8) do |url|
    #     fetch(url)
    #   end
    def self.map(items, threads: DEFAULT_THREADS, &block)
      return [] if items.empty?
      return items.map(&block) if items.size == 1

      # Limit threads to item count
      thread_count = [threads, items.size].min

      # Create indexed work items
      work_queue = Queue.new
      items.each_with_index { |item, idx| work_queue << [idx, item] }

      # Results array (pre-sized for thread safety with index assignment)
      results = Array.new(items.size)
      mutex = Mutex.new
      errors = []

      # Spawn worker threads
      workers = thread_count.times.map do
        Thread.new do
          loop do
            idx, item = work_queue.pop(true) rescue break
            begin
              results[idx] = yield(item)
            rescue => e
              mutex.synchronize { errors << e }
            end
          end
        end
      end

      # Wait for completion
      workers.each(&:join)

      # Re-raise first error if any occurred
      raise errors.first unless errors.empty?

      results
    end

    # Executes a block for each item in parallel, ignoring return values.
    # Useful for side-effect operations like file transfers.
    #
    # @param items [Array] Collection of items to process
    # @param threads [Integer] Number of parallel threads (default: 4)
    # @yield [item] Block to execute for each item
    def self.each(items, threads: DEFAULT_THREADS, &block)
      map(items, threads: threads, &block)
      nil
    end
  end
end
