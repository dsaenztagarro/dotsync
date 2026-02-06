# frozen_string_literal: true

module Dotsync
  # Simple thread-based parallel execution for independent operations.
  # Uses a configurable thread pool to process items concurrently.
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
