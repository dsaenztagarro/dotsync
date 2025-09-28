module Dotsync
  class Logger
    attr_accessor :output

    # 🎨 Nerd Font Icons
    ICONS = {
      info:    " ",
      watch:   " ",
      output:  " ",
      delete:  " ",
      bell:    " ",
      copy:    " ",
      skip:    " ",
      done:    " ",
      backup:  " ",
      clean:   " ",
    }

    def initialize(output = $stdout)
      @output = output
    end

    def log(type, message, icon: "")
      color = {
        info: 10, event: 141, delete: 31, copy: 32,
        skip: 33, done: 32, backup: 35,
        clean: 34
      }[type] || 0

      if icon != ""
        @output.puts "\e[38;5;#{color}m\e[1m#{ICONS[icon]}#{message}\e[0m"
      else
        @output.puts message
      end
    end
  end
end
