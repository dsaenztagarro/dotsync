module Dotsync
  class Logger
    attr_accessor :output

    # 🎨 Nerd Font Icons
    ICONS = {
      info:    " ",
      listen:  " ",
      error:   " ",
      watch:   " ",
      dest:    " ",
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

    def info(message, options = {})
      log(:info, message, options)
    end

    def action(message, options = {})
      log(:action, message, options)
    end

    def success(message)
      log(:success, message, icon: :done)
    end

    def error(message)
      log(:error, message, icon: :error)
    end

    def warning(message, options = {})
      log(:warning, message, options)
    end

    def log(type, message, options = {})
      icon = options[:icon]
      color = {
        info: 103, action: 153, error: 196, event: 141, warning: 31, copy: 32,
        skip: 33, done: 32, backup: 35,
        clean: 34
      }[type] || 0

      if icon.nil?
        @output.puts message
      else
        @output.puts "\e[38;5;#{color}m\e[1m#{ICONS[icon]}#{message}\e[0m"
      end
    end
  end
end
