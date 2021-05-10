#!/usr/bin/env ruby

require 'json'
require 'listen'
require 'readline'
require 'rspec/core'
require 'shellwords'

require_relative 'rspec-interactive/runner.rb'

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
      load_config(args[0])
    end

    def start()
      start_file_watcher
      load_history
      configure_auto_complete
      trap_interrupt
      start_console
    end

    private

    def load_config(name = nil)
      @config = get_config(name)
      load @config["init_script"]
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
      if args.empty?
        STDERR.puts "you must specify one or more spec files"
        return
      end

      # Allow wildcards.
      filenames = args.flat_map { |filename| Dir.glob(filename) }

      # Store formatters, if any, set by the init script. They will be cleared by RSpec below.
      formatters = RSpec.configuration.formatters || []

      # Initialize the runner. Also accessed by the signal handler above.
      # RSpecInteractive::Runner sets RSpec.world.wants_to_quit to false. The signal
      # handler sets it to true. 
      @mutex.synchronize { @runner = RSpecInteractive::Runner.new(filenames) }

      # Run the specs.
      @runner.run

      # Clear the runner.
      @mutex.synchronize { @runner = nil }

      # Clear data from previous run.
      RSpec.clear_examples

      # Formatters get cleared by clear_examples. I don't understand why but the actual run
      # also modifies the list of formatters. Reset them to whatever the init script set.
      if !RSpec.configuration.formatters.empty?
        raise "internal error. expected formatters to be cleared."
      end
      formatters.each { |f| RSpec.configuration.add_formatter(f) }
    end
  end
end
