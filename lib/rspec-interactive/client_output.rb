module RSpec
  module Interactive
    class ClientOutput
      def initialize(client)
        @client = client
      end

      def print(str = "")
        @client.print(str&.to_s || '')
      end

      def string
        @output
      end
    end
  end
end
