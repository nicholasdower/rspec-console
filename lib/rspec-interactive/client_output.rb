module RSpec
  module Interactive
    class ClientOutput
      def initialize(client)
        @client = client
      end

      def print(str = "")
        @client.print(str.to_s)
      end

      def write(str = "")
        @client.print(str.to_s)
      end

      def puts(str = "")
        @client.print(str.to_s + "\n")
      end

      def flush
      end

      def closed?
        @client.closed?
      end

      def string
        @output
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
