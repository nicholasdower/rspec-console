require 'json'
require 'listen'
require 'pry'
require 'readline'
require 'rspec/core'
require 'shellwords'

require 'rspec-interactive/runner'
require 'rspec-interactive/config'
require 'rspec-interactive/rspec_config_cache'
require 'rspec-interactive/input_completer'
require 'rspec-interactive/refresh_command'
require 'rspec-interactive/rspec_command'

module RSpec
  module Interactive

    DEFAULT_HISTORY_FILE = '.rspec_interactive_history'.freeze

    class << self
      attr_accessor :configuration
    end

    def self.configure(&block)
      block.call(@configuration)
    end

    def self.start(config_file: nil, initial_rspec_args: nil, history_file: DEFAULT_HISTORY_FILE, input_stream: STDIN, output_stream: STDOUT, error_stream: STDERR)
      @history_file = history_file
      @updated_files = []
      @stty_save = %x`stty -g`.chomp
      @mutex = Mutex.new
      @output_stream = output_stream
      @input_stream = input_stream
      @error_stream = error_stream
      @config_cache = RSpec::Interactive::ConfigCache.new

      @configuration = Configuration.new
      load config_file if config_file

      check_rails
      start_file_watcher
      trap_interrupt
      configure_pry

      @init_thread = Thread.start {
        @config_cache.record_configuration { @configuration.configure_rspec.call }
      }

      if initial_rspec_args
        open(@history_file, 'a') { |f| f.puts "rspec #{initial_rspec_args.strip}" }
        rspec Shellwords.split(initial_rspec_args)
      end

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

    def self.configure_rspec
      RSpec.configure do |config|
       config.error_stream = @error_stream
       config.output_stream = @output_stream
      end
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
      return if @configuration.watch_dirs.empty?

      # Only polling seems to work in Docker.
      @listener = Listen.to(*@configuration.watch_dirs, only: /\.rb$/, force_polling: true) do |modified, added|
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

    def self.refresh
      @mutex.synchronize do
        @updated_files.uniq.each do |filename|
          @output_stream.puts "changed: #{filename}"
          trace = TracePoint.new(:class) do |tp|
            @configuration.on_class_load.call(tp.self)
          end
          trace.enable
          load filename
          trace.disable
          @output_stream.puts
        end
        @updated_files.clear
      end
      @configuration.refresh.call
    end

    def self.rspec(args)
      if @init_thread&.alive?
        @init_thread.join
        @init_thread = nil
      end

      parsed_args = args.flat_map do |arg|
        if arg.match(/[\*\?\[]/)
          glob = Dir.glob(arg)
          glob.empty? ? [arg] : glob
        else
          [arg]
        end
      end

      refresh

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
