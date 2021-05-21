require 'rspec/core'

module RSpec
  module Interactive
    class Runner
      def initialize(args)
        ::RSpec.world.wants_to_quit = false
        @options = ::RSpec::Core::ConfigurationOptions.new(args)
      end

      def run()
        begin
          @options.configure(::RSpec.configuration)
          return if ::RSpec.world.wants_to_quit

          ::RSpec.configuration.load_spec_files
        ensure
          ::RSpec.world.announce_filters
        end

        return ::RSpec.configuration.reporter.exit_early(::RSpec.configuration.failure_exit_code) if ::RSpec.world.wants_to_quit

        example_groups = ::RSpec.world.ordered_example_groups
        examples_count = ::RSpec.world.example_count(example_groups)

        ::RSpec.configuration.reporter.report(examples_count) do |reporter|
          ::RSpec.configuration.with_suite_hooks do
            if examples_count == 0 && ::RSpec.configuration.fail_if_no_examples
              return ::RSpec.configuration.failure_exit_code
            end

            group_results = example_groups.map do |example_group|
              example_group.run(reporter)
            end

            success = group_results.all?
            exit_code = success ? 0 : 1
            if ::RSpec.world.non_example_failure
              success = false
              exit_code = ::RSpec.configuration.failure_exit_code
            end
            persist_example_statuses
            exit_code
          end
        end
      end

      def quit
        ::RSpec.world.wants_to_quit = true
      end

      def persist_example_statuses
        return if ::RSpec.configuration.dry_run
        return unless (path = ::RSpec.configuration.example_status_persistence_file_path)

        ::RSpec::Core::ExampleStatusPersister.persist(::RSpec.world.all_examples, path)
      rescue SystemCallError => e
        RSpec::Interactive.error_stream.puts "warning: failed to write results to #{path}"
      end
    end
  end
end
