module Spec
  module Runner
    module Formatter
      class TeamcityFormatter
        class << self
          attr_accessor :client
        end

        def log(msg)
          TeamcityFormatter.client.puts(msg)
          msg
        end
      end
    end
  end
end
