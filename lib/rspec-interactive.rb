#!/usr/bin/env ruby

require 'json'
require 'readline'
require 'rspec/core'
require 'shellwords'
require 'pry'

require 'rspec-interactive/runner'
require 'rspec-interactive/config_cache'

module RSpecInteractive
  class Console

    HISTORY_FILE = '.rspec_interactive_history'.freeze
    CONFIG_FILE = '.rspec_interactive_config'.freeze
    MAX_HISTORY_ITEMS = 100
    COMMANDS = ['help', 'rspec', 'pry', 'exit']

    def initialize(config, stty_save)
      @config = config
      @stty_save = stty_save
      @mutex = Mutex.new
      @runner = nil
      @config_cache = RSpecInteractive::ConfigCache.new
    end

    def self.start(args)
      if args.size > 1
        STDERR.puts "expected 0 or 1 argument, got: #{args.join(', ')}"
        exit!(1)
      end

      config = get_config(args[0])
      stty_save = %x`stty -g`.chomp

      Console.new(config, stty_save).start
    end

    def start
      load_rspec_config
      check_rails
      load_history
      configure_auto_complete
      trap_interrupt
      start_console
    end

    private

    def check_rails
      if defined?(Rails)
        if Rails.application.config.cache_classes
          STDERR.puts "warning: Rails.application.config.cache_classes enabled. Disable to ensure code is reloaded."
        end
      end
    end

    def load_rspec_config
      @config_cache.record_configuration(&rspec_configuration)
    end

    def rspec_configuration
      proc do
        if @config["init_script"]
          $LOAD_PATH << '.'
          require @config["init_script"]
        end
      end
    end

    def self.get_config(name = nil)
      unless File.exists? CONFIG_FILE
        STDERR.puts "WARNING: using default config, file not found: #{CONFIG_FILE}"
        return {}
      end

      configs = JSON.parse(File.read(CONFIG_FILE))["configs"] || []
      if configs.empty?
        STDERR.puts "no configs found in: #{CONFIG_FILE}"
        exit!(1)
      end

      # If a specific config was specified, use it.
      if name
        config = configs.find { |e| e["name"] == name }
        return config if config
        STDERR.puts "invalid config: #{name}"
        exit!(1)
      end

      # If there is only one, use it.
      if configs.size == 1
        return configs[0]
      end

      # Ask the user which to use.
      loop do
        names = configs.map { |e| e["name"] }
        names[0] = "#{names[0]} (default)"
        print "Multiple simultaneous configs not yet supported. Please choose a config. #{names.join(', ')}: "
        answer = STDIN.gets.chomp
        if answer.strip.empty?
          return configs[0]
        end
        config = configs.find { |e| e["name"] == answer }
        return config if config
        STDERR.puts "invalid config: #{answer}"
      end
    end

    def trap_interrupt
      trap('INT') do
        if @runner
          # We are on a different thread. There is a race here. Ignore nil.
          @runner&.quit
        else
          puts
          system "stty", @stty_save
          exit!(0)
        end
      end
    end

    def load_history
      if File.exists? HISTORY_FILE
        lines = File.readlines(HISTORY_FILE)
        lines.each do |line|
          Readline::HISTORY << line.strip
        end
      end
    end

    def configure_auto_complete
      Readline.completion_append_character = ""
    end

    def start_console
      loop do
        buffer = Readline.readline('> ', true)&.strip

        # Exit on ctrl-D.
        if !buffer
          puts
          system "stty", @stty_save
          exit!(0)
        end

        # Ignore blank lines.
        if buffer.empty?
          Readline::HISTORY.pop
          next
        end

        # Write history to file.
        if Readline::HISTORY.size > 0
          file = File.open(HISTORY_FILE, 'w')
          lines = Readline::HISTORY.to_a
          lines[-[MAX_HISTORY_ITEMS, lines.size].min..-1].each do |line|
            file.write(line.strip + "\n")
          end
          file.close
        end

        # Handle quoting, etc.
        args = Shellwords.shellsplit(buffer)
        next if args.empty?

        command = args[0].strip
        if COMMANDS.include?(command)
          send "command_#{command}".to_sym, args[1..-1]
        else
          STDERR.puts "command not found: #{args[0]}"
        end
      end
    end

    def command_help(args)
      if !args.empty?
        STDERR.puts "invalid argument(s): #{args}"
        return
      end

      print "commands:\n\n"
      print "help  - print this message\n"
      print "rspec - execute the specified spec file(s), wildcards allowed\n"
      print "pry   - start pry\n"
      print "exit  - exit\n"
    end

    def command_rspec(args)
      parsed_args = args.flat_map do |arg|
        if arg.match(/[\*\?\[]/)
          glob = Dir.glob(arg)
          glob.empty? ? [arg] : glob
        else
          [arg]
        end
      end

      # Prevent Pry from trapping too. It will break ctrl-c handling.
      Pry.config.should_trap_interrupts = false

      # Set Pry to use Readline, like us. This is the default anyway.
      Pry.config.input = Readline

      # If Pry does get used, it will add to history. We will clean that up after running the specs.
      history_size = Readline::HISTORY.size

      # Initialize the runner. Also accessed by the signal handler above.
      # RSpecInteractive::Runner sets RSpec.world.wants_to_quit to false. The signal
      # handler sets it to true. 
      @mutex.synchronize { @runner = RSpecInteractive::Runner.new(parsed_args) }

      # Run the specs.
      @runner.run

      # Clear the runner.
      @mutex.synchronize { @runner = nil }

      while Readline::HISTORY.size > history_size do
        Readline::HISTORY.pop
      end

      # Clear data from previous run.
      RSpec.reset

      @config_cache.replay_configuration
    end

    def command_pry(args)
      if args.size != 0
        STDERR.puts "unexpected argument(s): #{args}"
        return
      end

      history_size = Readline::HISTORY.size
      Pry.config.input = Readline
      Pry.config.should_trap_interrupts = false
      Pry.start
      while Readline::HISTORY.size > history_size do
        Readline::HISTORY.pop
      end
    end

    def command_exit(args)
      exit!(0)
    end
  end
end
