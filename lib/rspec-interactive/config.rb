module RSpec
  module Interactive
    class Configuration
      attr_accessor :watch_dirs, :on_class_load

      def initialize
        @watch_dirs = []
        @on_class_load = proc {}
      end

      def on_class_load(&block)
        return @on_class_load unless block
        @on_class_load = block
      end
    end
  end
end
