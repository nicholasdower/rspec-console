require 'rspec/core/option_parser'

# RSpec::Core::Parser calls abort on parse error. This kills the process.
# Here we replace abort so that it will raise instead.

# In some cases abort is called in response to an exception. If we simply raise,
# the original exception will be logged as the cause. This will lead to duplicate
# messaging. Here we define our own exception so that we can ensure no cause is
# logged.
class ParseError < StandardError
  def cause
    nil
  end
end

module RSpec::Core
  class Parser
    def abort(msg)
      raise ParseError.new(msg)
    end
  end
end
