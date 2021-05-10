require 'rspec/core'

module RSpecInteractive
  class Runner
    def initialize(args)
      RSpec.world.wants_to_quit = false
      @options = RSpec::Core::ConfigurationOptions.new(args)
    end

    def run()
      begin
        @options.configure(RSpec.configuration)
        return if RSpec.world.wants_to_quit

        RSpec.configuration.load_spec_files
      ensure
        RSpec.world.announce_filters
      end

      return RSpec.configuration.reporter.exit_early(RSpec.configuration.failure_exit_code) if RSpec.world.wants_to_quit

      example_groups = RSpec.world.ordered_example_groups
      examples_count = RSpec.world.example_count(example_groups)

      success = RSpec.configuration.reporter.report(examples_count) do |reporter|
        RSpec.configuration.with_suite_hooks do
          if examples_count == 0 && RSpec.configuration.fail_if_no_examples
            return RSpec.configuration.failure_exit_code
          end

          result = example_groups.map do |example_group|
            example_group.run(reporter)
          end

          result.all?
        end
      end

      success && !RSpec.world.non_example_failure ? 0 : RSpec.configuration.failure_exit_code
    end

    def quit
      RSpec.world.wants_to_quit = true
    end
  end
end
