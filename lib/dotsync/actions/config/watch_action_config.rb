# frozen_string_literal: true

module Dotsync
  class WatchActionConfig < PushActionConfig
    private
      SECTION_NAME = "watch"

      def section_name
        SECTION_NAME
      end
  end
end
