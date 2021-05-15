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
      :keep_retval => true
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
      result = RSpec::Interactive.runner.run
      RSpec::Interactive.runner = nil

      # Save results
      RSpec::Interactive.results << result
      RSpec::Interactive.result = result

      # Reenable history
      Pry.config.history_save = true

      # Reset
      RSpec.clear_examples
      RSpec.reset
      RSpec::Interactive.config_cache.replay_configuration

      Object.define_method :results do RSpec::Interactive.results end
      Object.define_method :result do RSpec::Interactive.result end

      puts "Result available at `result`. Result history available at `results`."
      puts

      if !RSpec::Interactive.result.success
        puts "Rerun failures by executing the previous command with --only-failures or --next-failure."
        puts
      end

      result
    end

    Pry::Commands.add_command(::RSpec::Interactive::RSpecCommand)
  end
end
