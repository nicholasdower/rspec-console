#!/usr/bin/env ruby

require 'json'
require 'listen'
require 'readline'
require 'rspec/core'
require 'shellwords'

require 'rspec-interactive/runner'
require 'rspec-interactive/config_cache'

module RSpecInteractive
  class Console

    HISTORY_FILE = '.rspec_interactive_history'.freeze
    CONFIG_FILE = '.rspec_interactive_config'.freeze
    MAX_HISTORY_ITEMS = 100
    COMMANDS = ['help', 'rspec']

    def initialize(args)
      if args.size > 1
        STDERR.puts "expected 0 or 1 argument, got: #{args.join(', ')}"
        exit!(1)
      end

      @stty_save = %x`stty -g`.chomp
      @mutex = Mutex.new
      @runner = nil
      @config_cache = RSpecInteractive::ConfigCache.new
      load_config(args[0])
    end

    def start()
      check_rails
      start_file_watcher
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

    def load_config(name = nil)
      @config = get_config(name)
      @config_cache.record_configuration(&rspec_configuration)
    end

    def rspec_configuration
      proc do
        $LOAD_PATH << '.'
        require @config["init_script"]
      end
    end

    def get_config(name = nil)
      if !File.exists? CONFIG_FILE
        STDERR.puts "file not found: #{CONFIG_FILE}"
        exit!(1)
      end

      configs = JSON.parse(File.read(CONFIG_FILE))["configs"]
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
        @mutex.synchronize do
          if @runner
            @runner.quit
          else
            puts
            system "stty", @stty_save
            exit!(0)
          end
        end
      end
    end

    def start_file_watcher
      # Only polling seems to work in Docker.
      listener = Listen.to(*@config["watch_dirs"], only: /\.rb$/, force_polling: true) do |modified, added, removed|
        (added + modified).each { |filename| load filename } 
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
          send command.to_sym, args[1..-1]
        else
          STDERR.puts "command not found: #{args[0]}"
        end
      end
    end

    def help(args)
      if !args.empty?
        STDERR.puts "invalid argument(s): #{args}"
        return
      end

      print "commands:\n\n"
      print "help  - print this message\n"
      print "rspec - execute the specified spec file(s), wildcards allowed\n"
    end

    def rspec(args)
      # Setup Pry in case it is used.
      if defined?(Pry)
        # Prevent Pry from trapping too. It will break ctrl-c handling.
        Pry.config.should_trap_interrupts = false

        # Set Pry to use Readline, like us. This is the default anyway.
        Pry.config.input = Readline
      end

      # If Pry does get used, it will add to history. We will clean that up after running the specs.
      history_size = Readline::HISTORY.size

      # Initialize the runner. Also accessed by the signal handler above.
      # RSpecInteractive::Runner sets RSpec.world.wants_to_quit to false. The signal
      # handler sets it to true. 
      @mutex.synchronize { @runner = RSpecInteractive::Runner.new(args) }

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
  end
end
