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
    end
  end
end
