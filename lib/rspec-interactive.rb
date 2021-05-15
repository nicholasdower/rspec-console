#!/usr/bin/env ruby

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

    HISTORY_FILE = '.rspec_interactive_history'.freeze
    CONFIG_FILE = '.rspec_interactive_config'.freeze
    RESULTS_FILE = '.rspec_interactive_results'.freeze

    class <<self
      attr_accessor :config, :stty_save, :mutex, :config_cache, :runner, :results, :result, :updated_files
    end

    def self.start(args)
      if args.size > 1
        STDERR.puts "expected 0 or 1 argument, got: #{args.join(', ')}"
        exit!(1)
      end

      @updated_files = []
      @results = []
      @config = get_config(args[0])
      @stty_save = %x`stty -g`.chomp
      @mutex = Mutex.new
      @config_cache = RSpec::Interactive::ConfigCache.new

      load_rspec_config
      check_rails
      start_file_watcher
      trap_interrupt
      configure_pry

      Pry.start
    end

    def self.check_rails
      if defined?(::Rails)
        if ::Rails.application.config.cache_classes
          STDERR.puts "warning: Rails.application.config.cache_classes enabled. Disable to ensure code is reloaded."
        end
      end
    end

    def self.load_rspec_config
      @config_cache.record_configuration(&rspec_configuration)
    end

    def self.configure_rspec
      RSpec.configure do |config|
        if !config.example_status_persistence_file_path
          config.example_status_persistence_file_path = RESULTS_FILE
        end
      end
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

    def self.start_file_watcher
      return unless @config["watch_dirs"]

      # Only polling seems to work in Docker.
      listener = Listen.to(*@config["watch_dirs"], only: /\.rb$/, force_polling: true) do |modified, added, removed|
        @mutex.synchronize do
          @updated_files.concat(added + modified)
        end
      end
      listener.start
    end

    def self.configure_pry
      # Prevent Pry from trapping too. It will break ctrl-c handling.
      Pry.config.should_trap_interrupts = false

      # Set Pry to use Readline. This is the default anyway.
      Pry.config.input = Readline

      # Use custom completer to get file completion.
      Pry.config.completer = RSpec::Interactive::InputCompleter

      Pry.config.history_file = HISTORY_FILE
    end
  end
end
