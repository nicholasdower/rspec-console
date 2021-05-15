#!/usr/bin/env ruby

require 'json'
require 'readline'
require 'rspec/core'
require 'pry'

require 'rspec-interactive/runner'
require 'rspec-interactive/config_cache'
require 'rspec-interactive/input_completer'

module RSpecInteractive
  class Console

    HISTORY_FILE = '.rspec_interactive_history'.freeze
    CONFIG_FILE = '.rspec_interactive_config'.freeze

    class <<self
      attr_accessor :config, :stty_save, :mutex, :runner, :config_cache
    end

    def self.start(args)
      if args.size > 1
        STDERR.puts "expected 0 or 1 argument, got: #{args.join(', ')}"
        exit!(1)
      end

      @config = get_config(args[0])
      @stty_save = %x`stty -g`.chomp
      @mutex = Mutex.new
      @runner = nil
      @config_cache = RSpecInteractive::ConfigCache.new

      load_rspec_config
      check_rails
      trap_interrupt
      configure_pry

      Pry::Commands.create_command "rspec" do
        description "Invoke RSpec."

        banner <<-BANNER
          Usage: rspec [arguments]

          See https://relishapp.com/rspec/rspec-core/docs/command-line.
        BANNER

        def process
          parsed_args = args.flat_map do |arg|
            if arg.match(/[\*\?\[]/)
              glob = Dir.glob(arg)
              glob.empty? ? [arg] : glob
            else
              [arg]
            end
          end

          runner = RSpecInteractive::Runner.new(parsed_args)
          RSpecInteractive::Console.runner = runner
          runner.run
          RSpecInteractive::Console.runner = nil
          RSpec.clear_examples
          RSpec.reset
          RSpecInteractive::Console.config_cache.replay_configuration
        end
      end

      Pry.start
    end

    def self.check_rails
      if defined?(Rails)
        if Rails.application.config.cache_classes
          STDERR.puts "warning: Rails.application.config.cache_classes enabled. Disable to ensure code is reloaded."
        end
      end
    end

    def self.load_rspec_config
      @config_cache.record_configuration(&rspec_configuration)
    end

    def self.rspec_configuration
      proc do
        if @config["init_script"]
          $LOAD_PATH << '.'
          require @config["init_script"]
        end
      end
    end

    def self.get_config(name = nil)
      unless File.exists? CONFIG_FILE
        STDERR.puts "warning: #{CONFIG_FILE} not found, using default config"
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

    def self.trap_interrupt
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

    def self.configure_pry
      # Prevent Pry from trapping too. It will break ctrl-c handling.
      Pry.config.should_trap_interrupts = false

      # Set Pry to use Readline. This is the default anyway.
      Pry.config.input = Readline

      # Use custom completer to get file completion.
      Pry.config.completer = RSpecInteractive::InputCompleter

      Pry.config.history_file = HISTORY_FILE
    end
  end
end
