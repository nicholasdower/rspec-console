module RSpec
  module Interactive
    class StringOutput
      attr_reader :string

      def initialize
        @string = ''
      end

      def write(name, str = "")
        @string += str.to_s
      end

      def puts(str = "")
        @string += str.to_s + "\n"
      end

      def print(str = "")
        @string += str.to_s
      end

      def flush
      end

      def closed?
        @client.closed?
      end

      def sync
        @sync || false
      end

      def sync=(sync)
        @sync = sync
      end

      def close
      end
    end
  end
end
