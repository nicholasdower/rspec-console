require 'json'
require 'listen'
require 'pry'
require 'readline'
require 'rspec/core'

require 'rspec-interactive/runner'
require 'rspec-interactive/config_cache'
require 'rspec-interactive/input_completer'
require 'rspec-interactive/rspec_command'

module RSpec
  module Interactive

    DEFAULT_HISTORY_FILE = '.rspec_interactive_history'.freeze
    DEFAULT_CONFIG_FILE = '.rspec_interactive_config'.freeze

    def self.start(args, config_file: DEFAULT_CONFIG_FILE, history_file: DEFAULT_HISTORY_FILE, input_stream: STDIN, output_stream: STDOUT, error_stream: STDERR)
      if args.size > 1
        @error_stream.puts "expected 0 or 1 argument, got: #{args.join(', ')}"
        return 1
      end

      @config_file = config_file
      @history_file = history_file
      @updated_files = []
      @stty_save = %x`stty -g`.chomp
      @mutex = Mutex.new
      @output_stream = output_stream
      @input_stream = input_stream
      @error_stream = error_stream
      @config_cache = RSpec::Interactive::ConfigCache.new

      @config = get_config(args[0])
      return 1 unless @config

      load_rspec_config
      check_rails
      start_file_watcher
      trap_interrupt
      configure_pry

      Pry.start
      @listener.stop if @listener
      0
    end

    def self.check_rails
      if defined?(::Rails)
        if ::Rails.application.config.cache_classes
          @error_stream.puts "warning: Rails.application.config.cache_classes enabled. Disable to ensure code is reloaded."
        end
      end
    end

    def self.load_rspec_config
      @config_cache.record_configuration(&rspec_configuration)
    end

    def self.configure_rspec
      RSpec.configure do |config|
       config.error_stream = @error_stream
       config.output_stream = @output_stream
      end
    end

    def self.rspec_configuration
      proc do
        if @config["init_script"]
          load @config["init_script"]
        end
      end
    end

    def self.get_config(name = nil)
      unless @config_file && File.exists?(@config_file)
        unless name.nil?
          @error_stream.puts "invalid config: #{name}"
          return nil
        end

        @error_stream.puts "warning: config file not found, using default config" if @config_file
        return {}
      end

      begin
        configs = JSON.parse(File.read(@config_file))["configs"] || []
      rescue JSON::ParserError => e
        @error_stream.puts "failed to parse config file"
        return nil
      end

      if configs.empty?
        @error_stream.puts "no configs found in config file"
        return nil
      end

      # If a specific config was specified, use it.
      if name
        config = configs.find { |e| e["name"] == name }
        return config if config
        @error_stream.puts "invalid config: #{name}"
        return nil
      end

      # If there is only one, use it.
      if configs.size == 1
        return configs[0]
      end

      @error_stream.puts "multiple configurations found, you must specify which to use"
      return nil
    end

    def self.trap_interrupt
      trap('INT') do
        if @runner
          # We are on a different thread. There is a race here. Ignore nil.
          @runner&.quit
        else
          @output_stream.puts
          system "stty", @stty_save
          exit!(0)
        end
      end
    end

    def self.start_file_watcher
      return unless @config["watch_dirs"]

      # Only polling seems to work in Docker.
      @listener = Listen.to(*@config["watch_dirs"], only: /\.rb$/, force_polling: true) do |modified, added, removed|
        @mutex.synchronize do
          @updated_files.concat(added + modified)
        end
      end
      @listener.start
    end

    def self.configure_pry
      # Prevent Pry from trapping too. It will break ctrl-c handling.
      Pry.config.should_trap_interrupts = false

      # Set up IO.
      Pry.config.input = Readline
      Pry.config.output = @output_stream
      Readline.output = @output_stream
      Readline.input = @input_stream

      # Use custom completer to get file completion.
      Pry.config.completer = RSpec::Interactive::InputCompleter

      Pry.config.history_file = @history_file
    end

    def self.rspec(args)
      parsed_args = args.flat_map do |arg|
        if arg.match(/[\*\?\[]/)
          glob = Dir.glob(arg)
          glob.empty? ? [arg] : glob
        else
          [arg]
        end
      end

      @mutex.synchronize do
        @updated_files.uniq.each do |filename|
          @output_stream.puts "modified: #{filename}"
          trace = TracePoint.new(:class) do |tp|
            if defined?(ApplicationRecord) && tp.self < ApplicationRecord
              @output_stream.puts "clearing ActiveRecord validators via #{tp.self}.clear_validators!"
              tp.self.clear_validators!
            end
          end
          trace.enable
          load filename
          trace.disable
          @output_stream.puts
        end
        @updated_files.clear
      end

      @runner = RSpec::Interactive::Runner.new(parsed_args)

      # Stop saving history in case a new Pry session is started for debugging.
      Pry.config.history_save = false

      # RSpec::Interactive-specific RSpec configuration
      configure_rspec

      # Run.
      exit_code = @runner.run
      @runner = nil

      # Reenable history
      Pry.config.history_save = true

      # Reset
      RSpec.clear_examples
      RSpec.reset
      @config_cache.replay_configuration
    end
  end
end
