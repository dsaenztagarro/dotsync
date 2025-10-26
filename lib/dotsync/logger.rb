module Dotsync
  class Logger
    attr_accessor :output

    # NOTE: use Rake tasks "palette:fg" and "palette:bg" to select a proper ASCII color code

    def initialize(output = $stdout)
      @output = output
    end

    def action(message, color: 153, bold: true, icon: :console)
      log(message, color: color, bold: bold, icon: icon)
    end

    def info(message, color: 103, bold: true, icon: :info)
      log(message, color: color, bold: bold, icon: icon)
    end

    def error(message, color: 196, bold: true, icon: :error)
      log(message, color: color, bold: bold, icon: icon)
    end

    def log(message, color: 0, bold: false, icon: nil)
      mapped_icon = Dotsync::Icons::MAPPINGS[icon] if icon

      msg = []
      msg << "\e[38;5;#{color}m" if color > 0
      msg << "\e[1m" if bold
      msg << mapped_icon if mapped_icon
      msg << message
      msg << "\e[0m" if color > 0 # reset color
      msg = msg.join("")

      @output.puts msg
    end
  end
end
