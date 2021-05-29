module RSpec
  module Interactive
    class Configuration
      attr_accessor :watch_dirs

      def initialize
        @watch_dirs = []
      end
    end
  end
end
