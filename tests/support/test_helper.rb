ENV['TERM'] = 'dumb'

require 'pry'
require 'readline'
require 'rspec/core'
require 'rspec-interactive'
require 'timeout'
require 'time'
require_relative 'ansi'

class Time
  @start = Time.parse('1982-08-05 07:21:00 -0500')

  def self.now
   @start
 end
end

module RSpec::Core
 class Time
   def self.now
     ::Time.now
   end
 end
end

class Output
  def initialize
    @output = ""
    @pos = 0
  end

  def print(string)
    return if string == nil || string == "\e[0G"
    @output += string
  end

  def puts(string = "")
    string = "" if string == nil
    print(string + "\n")
  end

  def closed?
    false
  end

  def tty?
    false
  end

  def flush
  end

  def next_string
    output = @output[@pos..-1]
    @pos = @output.size
    output
  end

  def string
    @output
  end
end

module Readline
  class << self
    attr_accessor :error
  end

  @original_readline = method(:readline)

  def self.reset
    @next_response = []
    @signal = ConditionVariable.new
    @mutex = Mutex.new
    @state = :waiting_for_prompt
    @error = nil
  end

  reset

  def self.readline(prompt = nil, save_history = nil)
    temp = nil
    input_read = nil
    @mutex.synchronize do
      Thread.current.kill if @error

      if @state != :waiting_for_prompt
        @error = "prompted in invalid state: #{@state}"
        Thread.current.kill
      end

      @state = :prompted
      @signal.signal
      @signal.wait(@mutex, 1)

      if @state != :response_available
        @error = "sending response in invalid state: #{@state}"
        Thread.current.kill
      end
      @state = :waiting_for_prompt

      if @next_response.empty?
        @error = "readline response signaled with nothing to respond with"
        Thread.current.kill
      end
      if @next_response.size > 1
        @error = "readline response signaled with too much to respond with"
        Thread.current.kill
      end

      temp = Tempfile.new('input')
      temp.write("#{@next_response[0]}\n")
      temp.rewind
      input_read = File.new(temp.path, 'r')
      Readline.input = input_read

      @next_response.clear

      @original_readline.call(prompt, save_history)
    end
  ensure
    temp&.close
    input_read&.close
  end

  def self.await_readline
    @mutex.synchronize do
      raise @error if @error
      @signal.wait(@mutex, 1)
      raise @error if @error
      if @state != :prompted
        @error = "timed out waiting for prompt"
        raise @error
      end
    end
  end

  def self.puts(string)
    @mutex.synchronize do
      raise @error if @error
      if @state != :prompted
        @error = "puts called in invalid state: #{@state}"
        raise @error
      end
      @next_response << string
      @state = :response_available
      @signal.signal
    end
  end

  def self.ctrl_d
    puts(nil)
  end
end

class Test

  def self.test(name, args: [], config_path: nil, &block)
    Test.new.run(name, args, config_path, &block)
  end

  def run(name, args, config_path, &block)
    puts "running: #{name}"

    @output_temp_file = Tempfile.new('output')
    @output_write = File.open(@output_temp_file.path, 'w')

    @error_temp_file = Tempfile.new('error')
    @error_write = File.open(@error_temp_file.path, 'w')

    @history_temp_file = Tempfile.new('history')

    @interactive_thread = Thread.start do
      @result = RSpec::Interactive.start(
        args,
        config_file: config_path,
        history_file: @history_temp_file.path,
        input_stream: STDIN,
        output_stream: @output_write,
        error_stream: @error_write)
    end

    begin
      instance_eval &block
    rescue Exception => e
      failed = true
      STDERR.puts e.message
      e.backtrace[0..5].each { |line| STDERR.puts "  #{line}" }
    end

    await_termination

    if Readline.error
      failed = true
      STDOUT.puts Readline.error
    end

    if failed
      Ansi.puts :red, "failed: #{name}"
    else
      Ansi.puts :green, "passed: #{name}"
    end
    puts
  ensure
    @output_write.close
    @output_temp_file.close

    @error_write.close
    @error_temp_file.close

    @history_temp_file.close

    Readline.reset
    Pry.reset_defaults
  end

  def await_termination
    Timeout.timeout(5) do
      @interactive_thread.join
    end
  rescue Timeout::Error => e
    @interactive_thread.kill
    raise "timed out waiting for interactive session to terminate"
  end

  def await_prompt
    Readline.await_readline
  end

  def input(string)
    Readline.puts(string)
  end

  def output
    @output_temp_file.rewind
    File.read(@output_temp_file.path).gsub("\e[0G", "")
  end

  def error_output
    @error_write.flush
    @error_temp_file.rewind
    File.read(@error_temp_file.path)
  end

  def expect_history(expected)
    @history_temp_file.rewind
    history = File.read(@history_temp_file.path)
    if expected != history
      raise "unexpected history:\n  expected: #{expected.inspect}\n  actual:   #{history.inspect}"
    end
  end

  def expect_output(expected)
    if expected != output
      raise "unexpected output:\n  expected: #{expected.inspect}\n  actual:   #{output.inspect}"
    end
  end

  def expect_error_output(expected)
    if expected != error_output
      raise "unexpected error output:\n  expected: #{expected.inspect}\n  actual:   #{error_output.inspect}"
    end
  end

  def expect_result(expected)
    if expected != @result
      raise "unexpected result:\n  expected: #{expected.inspect}\n  actual:   #{@result.inspect}"
    end
  end
end
