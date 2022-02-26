require 'json'
require 'listen'
require 'pry'
require 'readline'
require 'rspec/core'
require 'shellwords'
require 'socket'
require 'teamcity/spec/runner/formatter/teamcity/formatter'

require 'rspec-interactive/client_output'
require 'rspec-interactive/config'
require 'rspec-interactive/input_completer'
require 'rspec-interactive/pry'
require 'rspec-interactive/refresh_command'
require 'rspec-interactive/rspec_command'
require 'rspec-interactive/rspec_config_cache'
require 'rspec-interactive/rspec_core_example'
require 'rspec-interactive/rubo_cop_command'
require 'rspec-interactive/runner'
require 'rspec-interactive/stdio'

module RSpec
  module Interactive

    DEFAULT_HISTORY_FILE = '.rspec_interactive_history'.freeze
    DEFAULT_PORT = 5678

    class << self
      attr_accessor :configuration
    end

    def self.configure(&block)
      block.call(@configuration)
    end

    def self.start(
      config_file:   nil,
      server:        false,
      port:          DEFAULT_PORT,
      history_file:  DEFAULT_HISTORY_FILE,
      input_stream:  STDIN,
      output_stream: STDOUT,
      error_stream:  STDERR)

      @history_file = history_file
      @updated_files = []
      @stty_save = %x`stty -g`.chomp
      @file_change_mutex = Mutex.new
      @command_mutex = Mutex.new
      @output_stream = output_stream
      @input_stream = input_stream
      @error_stream = error_stream
      @config_cache = RSpec::Interactive::ConfigCache.new

      @configuration = Configuration.new
      load config_file if config_file

      check_rails
      trap_interrupt
      configure_pry

      @startup_thread = Thread.start do
        @config_cache.record_configuration { @configuration.configure_rspec.call }
        start_file_watcher

        if server
          server_thread = Thread.start do
            server = TCPServer.new port

            while client = server.accept
              request = client.gets
              args = Shellwords.split(request)
              rspec_for_server(client, args)
              client.close
            end
          end
        end
      end

      Pry.start
      @listener.stop if @listener
      server_thread.exit if server_thread
      0
    end

    def self.check_rails
      if defined?(::Rails)
        if ::Rails.application.config.cache_classes
          @error_stream.puts "warning: Rails.application.config.cache_classes enabled. Disable to ensure code is reloaded."
        end
      end
    end

    def self.trap_interrupt
      trap('INT') do
        if @runner
          # We are on a different thread. There is a race here. Ignore nil.
          @runner&.quit
        else
          raise Interrupt
        end
      end
    end

    def self.start_file_watcher
      return if @configuration.watch_dirs.empty?

      # Only polling seems to work in Docker.
      @listener = Listen.to(*@configuration.watch_dirs, only: /\.rb$/, force_polling: true) do |modified, added|
        @file_change_mutex.synchronize do
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
      @file_change_mutex.synchronize do
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

    def self.parse_args(args)
      i = 0
      parsed_args = []
      until i == args.length
        case args[i]
        when /[\*\?\[]/
          glob = Dir.glob(args[i])
          parsed_args.concat(glob.empty? ? args[i] : glob)
        when '--pattern'
          # RubyMine passes --pattern when running all specs in a dir.
          # We don't want to expand this since it is used as a glob by RSpec.
          parsed_args.concat(args[i..(i + 1)])
          i += 1
        else
          parsed_args << args[i]
        end
        i += 1
      end
      parsed_args
    end

    def self.rspec(args)
      @runner = RSpec::Interactive::Runner.new(parse_args(args))

      refresh

      # Stop saving history in case a new Pry session is started for debugging.
      Pry.config.history_save = false

      # RSpec::Interactive-specific RSpec configuration
      RSpec.configure do |config|
       config.error_stream = @error_stream
       config.output_stream = @output_stream
       config.start_time = RSpec::Core::Time.now
      end

      # Run.
      exit_code = @runner.run
      @runner = nil

      # Reenable history
      Pry.config.history_save = true

      # Reset
      RSpec.clear_examples
      RSpec.reset
      @config_cache.replay_configuration
    ensure
      @runner = nil
    end

    def self.rspec_for_server(client, args)
      @command_mutex.synchronize do
        # Prevent the debugger from being used. The server isn't interactive.
        disable_pry = ENV['DISABLE_PRY']
        ENV['DISABLE_PRY'] = 'true'

        Stdio.capture(ClientOutput.new(client)) do
          @runner = RSpec::Interactive::Runner.new(parse_args(args))

          refresh

          # RSpec::Interactive-specific RSpec configuration
          RSpec.configure do |config|
           config.error_stream = @error_stream
           config.output_stream = @output_stream
           config.start_time = RSpec::Core::Time.now
          end

          # RubyMine specifies --format. That causes a formatter to be added. It does not override
          # the existing formatter (if one is set by default). Clear any formatters but resetting
          # the loader.
          RSpec.configuration.instance_variable_set(
            :@formatter_loader,
            RSpec::Core::Formatters::Loader.new(RSpec::Core::Reporter.new(RSpec.configuration)))

          # Always use the teamcity formatter, even though RubyMine always specifies it.
          # This make manual testing of rspec-interactive easier.
          RSpec.configuration.formatter = Spec::Runner::Formatter::TeamcityFormatter

          # Run.
          exit_code = @runner.run

          # Reset
          RSpec.clear_examples
          RSpec.reset
          @config_cache.replay_configuration
        end
      ensure
        ENV['DISABLE_PRY'] = disable_pry
      end
    end

    def self.rubo_cop(args)
      if defined?(RuboCop)
        RuboCop::CLI.new.run args
      else
        @error_stream.puts "fatal: RuboCop not found. Is the gem installed in this project?"
      end
    end

    def self.eval(&block)
      if Thread.current.thread_variable_get('holding_lock')
        yield
      else
        @command_mutex.synchronize do
          Thread.current.thread_variable_set('holding_lock', true)
          if @startup_thread
            @startup_thread.join
            @startup_thread = nil
          end
          yield
        ensure
          Thread.current.thread_variable_set('holding_lock', false)
        end
      end
    end
  end
end
