require 'rspec/core'

module RSpec
  module Interactive
    class ExampleGroupResult
      attr_accessor :group, :success

      def initialize(group, success)
        @group = group
        @success = success
      end
    end

    class Result
      attr_accessor :groups, :success, :exit_code

      def initialize(groups, success, exit_code)
        @groups = groups
        @success = success
        @exit_code = exit_code
      end

      def inspect(original = false)
        original ? super() : "<RSpec::Interactive::Result @success=#{@success}, @groups=[...]>"
      end
    end

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

        result = RSpec.configuration.reporter.report(examples_count) do |reporter|
          RSpec.configuration.with_suite_hooks do
            if examples_count == 0 && RSpec.configuration.fail_if_no_examples
              return RSpec.configuration.failure_exit_code
            end

            results = example_groups.map do |example_group|
              group_success = example_group.run(reporter)
              ExampleGroupResult.new(example_group, group_success)
            end

            success = results.all?(&:success)
            exit_code = success ? 0 : 1
            if RSpec.world.non_example_failure
              success = false
              exit_code = RSpec.configuration.failure_exit_code
            end
            Result.new(results, success, exit_code)
          end
        end
        RSpec::Interactive.results ||= []
        RSpec::Interactive.results << result
        RSpec::Interactive.result = result
        result
      end

      def quit
        RSpec.world.wants_to_quit = true
      end
    end
  end
end
