module RSpec
  module Interactive
    class Configuration
      attr_accessor :watch_dirs, :configure_rspec, :on_class_load

      def initialize
        @watch_dirs      = []
        @configure_rspec = proc {}
        @on_class_load   = proc {}
      end

      def configure_rspec(&block)
        return @configure_rspec unless block
        @configure_rspec = block
      end

      def on_class_load(&block)
        return @on_class_load unless block
        @on_class_load = block
      end
    end
  end
end
