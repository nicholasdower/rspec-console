require 'rspec/core'

module RSpec
  module Core
    class Example
      alias_method :old_run, :run

      def run(example_group_instance, reporter)
        execution_result.started_at = RSpec::Core::Time.now
        old_run(example_group_instance, reporter)
      end
    end
  end
end

