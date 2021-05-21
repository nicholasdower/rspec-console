# frozen_string_literal: true

module RSpec::Interactive
  class RSpecCommand < Pry::ClassCommand
    match 'rspec'
    description "Invoke RSpec."

    banner <<-BANNER
      Usage: rspec [arguments]

      See https://relishapp.com/rspec/rspec-core/docs/command-line.
    BANNER

    command_options(
      :keep_retval => false
    )

    def process
      parsed_args = args.flat_map do |arg|
        if arg.match(/[\*\?\[]/)
          glob = Dir.glob(arg)
          glob.empty? ? [arg] : glob
        else
          [arg]
        end
      end

      RSpec::Interactive.mutex.synchronize do
        RSpec::Interactive.updated_files.uniq.each do |filename|
          load filename
        end
        RSpec::Interactive.updated_files.clear
      end

      RSpec::Interactive.runner = RSpec::Interactive::Runner.new(parsed_args)

      # Stop saving history in case a new Pry session is started for debugging.
      Pry.config.history_save = false

      # RSpec::Interactive-specific RSpec configuration
      RSpec::Interactive.configure_rspec

      # Run.
      exit_code = RSpec::Interactive.runner.run
      RSpec::Interactive.runner = nil

      # Reenable history
      Pry.config.history_save = true

      # Reset
      RSpec.clear_examples
      RSpec.reset
      RSpec::Interactive.config_cache.replay_configuration

      if exit_code != 0 && ::RSpec.configuration.example_status_persistence_file_path
        RSpec::Interactive.output_stream.puts "Rerun failures by executing the previous command with --only-failures or --next-failure."
        RSpec::Interactive.output_stream.puts
      end
    end

    Pry::Commands.add_command(::RSpec::Interactive::RSpecCommand)
  end
end
