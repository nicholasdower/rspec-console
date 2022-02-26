module RSpec
  module Interactive
    class StringOutput
      attr_reader :string

      def initialize
        @string = ''
      end

      def print(str = "")
        @string += str&.to_s || ''
      end
    end
  end
end
