module Dotsync
  module Loggable
    # 🎨 Nerd Font Icons
    ICONS = {
      info:    " ",
      delete:  " ",
      copy:    " ",
      skip:    " ",
      done:    " ",
      backup:  " ",
      clean:   " ",
    }

    class Logger
      attr_accessor :output

      def initialize(output = $stdout)
        @output = output
      end

      def log(type, message)
        color = {
          info: 36, delete: 31, copy: 32,
          skip: 33, done: 32, backup: 35,
          clean: 34
        }[type] || 0

        @output.puts "\e[1;#{color}m#{ICONS[type]} #{message}\e[0m"
      end
    end
  end
end

