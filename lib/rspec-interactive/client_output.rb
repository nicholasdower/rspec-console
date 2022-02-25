module RSpec
  module Interactive
    class ClientOutput
      def initialize(client)
        @client = client
      end

      def puts(str = "")
        @client.puts(str&.to_s || '')
      end

      def string
        @output
      end
    end
  end
end
