# frozen_string_literal: true

module Dotsync
  class ContentDiff
    COLORS = {
      header: 103,       # Purple for file headers
      hunk: 36,          # Cyan for @@ lines
      addition: 34,      # Blue for added lines (consistent with diff_additions)
      deletion: 88,      # Red for removed lines (consistent with diff_removals)
      context: 240       # Gray for context lines
    }.freeze

    def initialize(src_path, dest_path, logger)
      @src_path = src_path
      @dest_path = dest_path
      @logger = logger
    end

    def display
      return unless displayable?

      diff_output = generate_diff
      return if diff_output.empty?

      display_header
      colorize_and_display(diff_output)
    end

    private
      def displayable?
        text_file?(@src_path) && text_file?(@dest_path)
      end

      def text_file?(path)
        return false unless File.file?(path)

        # Check if file appears to be text by reading first few bytes
        begin
          sample = File.read(path, 8192) || ""
          # Binary files typically contain null bytes
          !sample.include?("\x00")
        rescue StandardError
          false
        end
      end

      def generate_diff
        # Use system diff with unified format
        # diff returns exit code 1 when files differ, so we can't use backticks directly
        output = `diff -u "#{@dest_path}" "#{@src_path}" 2>/dev/null`
        output.lines.drop(2).join # Drop the first two header lines, we'll add our own
      rescue StandardError
        ""
      end

      def display_header
        @logger.log("--- #{@dest_path}", color: COLORS[:header])
        @logger.log("+++ #{@src_path}", color: COLORS[:header])
      end

      def colorize_and_display(diff_output)
        diff_output.each_line do |line|
          color = line_color(line)
          @logger.log(line.chomp, color: color)
        end
        @logger.log("")
      end

      def line_color(line)
        case line[0]
        when "+"
          COLORS[:addition]
        when "-"
          COLORS[:deletion]
        when "@"
          COLORS[:hunk]
        else
          COLORS[:context]
        end
      end
  end
end
