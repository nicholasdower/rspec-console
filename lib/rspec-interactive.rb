require 'find'
require 'json'
require 'pry'
require 'readline'
require 'rspec/core'
require 'set'
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
require 'rspec-interactive/string_output'
require 'rspec-interactive/threaded_output'

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
      @rspec_mutex = Mutex.new
      @output_stream = output_stream
      @input_stream = input_stream
      @error_stream = error_stream
      @config_cache = RSpec::Interactive::ConfigCache.new

      @configuration = Configuration.new
      load config_file if config_file

      check_rails
      maybe_trap_interrupt
      configure_pry
      configure_watched_files

      @startup_thread = Thread.start do
        Thread.current.report_on_exception = false

        if server
          @server_thread = Thread.start do
            begin
              server = TCPServer.new port
            rescue StandardError => e
              log_exception(@output_stream, e)
              exit 1
            end

            while true
              break unless client = server.accept
              begin
                request = client.gets
                args = Shellwords.split(request)
                rspec_for_server(client, args)
              rescue StandardError => e
                # It would be nice to log to the client here but it might be
                # disconnected or disconnect before we successfully write. Any
                # error here is unexpected so just log to the console.
                @output_stream.puts
                @output_stream.puts 'error handling client request'
                log_exception(@output_stream, e)
              ensure
                client.close
              end
            end
          end
        end

        @startup_output = StringOutput.new
        output = ThreadedOutput.new(thread_map: { Thread.current => @startup_output }, default: @output_stream)

        Stdio.capture(stdout: output, stderr: output) do
          @config_cache.record_configuration { @configuration.configure_rspec.call }
        end
      end

      Pry.start
      @server_thread.exit if @server_thread
      @startup_thread.exit if @startup_thread
      0
    end

    def self.check_rails
      if defined?(::Rails)
        if ::Rails.application.config.cache_classes
          @error_stream.puts "warning: Rails.application.config.cache_classes enabled. Disable to ensure code is reloaded."
        end
      end
    end

    def self.maybe_trap_interrupt
      return unless RbConfig::CONFIG['ruby_install_name'] == 'jruby'

      # When on JRuby, Pry traps interrupts and raises an Interrupt exception.
      # Unfortunately, raising Interrupt is not enough when RSpec is running since it
      # will only cause the current example to fail. We want to kill RSpec entirely
      # if it is running so here we disable Pry's handling and rewrite it to include
      # special handling for RSpec.

      Pry.config.should_trap_interrupts = false

      trap('INT') do
        if @runner
          # We are on a different thread. There is a race here. Ignore nil.
          @runner&.quit
        else
          raise Interrupt
        end
      end
    end

    def self.configure_pry
      # Set up IO.
      Pry.config.input = Readline
      Pry.config.output = @output_stream
      Readline.output = @output_stream
      Readline.input = @input_stream

      # Use custom completer to get file completion.
      Pry.config.completer = RSpec::Interactive::InputCompleter

      Pry.config.history_file = @history_file
    end

    def self.refresh(output: @output_stream)
      get_updated_files.each do |filename|
        output.puts "changed: #{filename}"
        trace = TracePoint.new(:class) do |tp|
          @configuration.on_class_load.call(tp.self)
        end
        trace.enable
        load filename
        trace.disable
        output.puts
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
      @rspec_mutex.synchronize do
        begin
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
          @runner.run
        ensure
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

    def self.rspec_for_server(client, args)
      @rspec_mutex.synchronize do
        disable_pry = ENV['DISABLE_PRY']
        output = ClientOutput.new(client)

        ENV['TEAMCITY_RAKE_RUNNER_DEBUG_OUTPUT_CAPTURER_ENABLED'] = 'false'
        Rake::TeamCity::RunnerCommon.class_variable_set(:@@original_stdout, output)

        return unless await_startup(output: output)

        Stdio.capture(stdout: output, stderr: output) do
          # Prevent the debugger from being used. The server isn't interactive.
          ENV['DISABLE_PRY'] = 'true'

          runner = RSpec::Interactive::Runner.new(parse_args(args))

          refresh(output: output)

          # RSpec::Interactive-specific RSpec configuration
          RSpec.configure do |config|
           config.error_stream = output
           config.output_stream = output
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
          runner.run
        rescue Errno::EPIPE, IOError
          # Don't care.
        ensure
          ENV['DISABLE_PRY'] = disable_pry
          runner = nil

          # Reset
          RSpec.clear_examples
          RSpec.reset

          @config_cache.replay_configuration
        end
      end
    end

    def self.rubo_cop(args)
      if defined?(RuboCop)
        RuboCop::CLI.new.run args
      else
        @error_stream.puts "fatal: RuboCop not found. Is the gem installed in this project?"
      end
    end

    def self.eval(line, options, &block)
      return yield if line.nil? # EOF
      return yield if line.empty? # blank line

      if await_startup
        yield
      else
        @output_stream.puts
        true
      end
    end

    def self.await_startup(output: @output_stream)
      return true unless @startup_thread

      if @startup_thread.alive?
        output.puts 'waiting for configure_rspec...'
      end

      begin
        @startup_thread.join
        @startup_thread = nil
        print_startup_output(output: output)
        true
      rescue Interrupt
        false
      rescue StandardError => e
        print_startup_output(output: output)
        output.puts 'configure_rspec failed'
        log_exception(output, e)
        false
      end
    end

    def self.log_exception(output, e)
      output.puts "#{e.backtrace[0]}: #{e.message} (#{e.class})"
      e.backtrace[1..-1].each { |b| output.puts "\t#{b}" }
    end

    def self.print_startup_output(output: @output_stream)
      return if @startup_output.nil? || @startup_output.string.empty?

      output.puts(@startup_output.string)
      @startup_output = nil
    end

    def self.configure_watched_files
      @watched_files = get_watched_files
    end

    def self.get_watched_files
      return Set.new if @configuration.watch_dirs.empty?
      entries = Find.find(*@configuration.watch_dirs).flat_map do |file|
        if FileTest.file?(file)
          [[file, File.mtime(file).to_i]]
        else
          []
        end
      end
      entries.to_set
    end

    def self.get_updated_files
      new_watched_files = get_watched_files
      difference = new_watched_files - @watched_files
      @watched_files = new_watched_files
      difference.map(&:first)
    end
  end
end
