ENV['TERM'] = 'dumb'

require 'pry'
require 'readline'
require 'rspec/core'
require 'rspec-interactive'
require "timeout"
require_relative 'ansi'

class Time
  @start = Time.at(Time.now.to_i)

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
    attr_accessor :output, :fake
  end

  def self.output=(output_stream)
    @fake.output = output_stream
  end

  def self.readline(prompt = nil, something = nil)
    @fake.readline(prompt, something)
  end
end

class FakeReadline
  attr_accessor :output, :error

  def initialize
    @queue = Queue.new
    @readline_signal = ConditionVariable.new
    @puts_signal = ConditionVariable.new
    @mutex = Mutex.new
    @prompted = false
    @error = nil
    @output = nil
  end

  def readline(prompt = nil, something = nil)
    @mutex.synchronize do
      raise "unexpected readline call after error" if @error
      @output.print prompt
      @prompted = true
      @readline_signal.signal
      @puts_signal.wait(@mutex, 1)
      @prompted = false
      if @queue.size != 1
        @error = "readline response signaled with nothing to respond with"
        Thread.current.kill
      end
      result = @queue.pop
      @output.puts result
      result
    end
  end

  def await_readline
    @mutex.synchronize do
      raise @error if @error
      @readline_signal.wait(@mutex, 1)
      raise @error if @error
      if !@prompted
        @error = "timed out waiting for prompt"
        raise @error
      end
    end
  end

  def puts(string)
    @mutex.synchronize do
      raise @error if @error
      @queue << string
      @puts_signal.signal
    end
  end

  def ctrl_d
    puts(nil)
  end
end

class Test

  def initialize
    @output_stream = Output.new
    @readline = FakeReadline.new
  end

  def self.test(name, &block)
    Test.new.run(name, &block)
  end

  def run(name, &block)
    @interactive_thread = Thread.start do
      begin
        Readline.fake = @readline
        RSpec::Interactive.start(ARGV, input_stream: STDIN, output_stream: @output_stream, error_stream: @output_stream)
      ensure
        Readline.fake = nil
      end
    end

    begin
      instance_eval &block
    rescue Exception => e
      failed = true
      Ansi.puts :red, "failed: #{name}\n#{e.message}"
    end

    await_termination

    if @readline.error
      failed = true
      Ansi.puts :red, "failed: #{name}\n#{@readline.error}"
    end

    if !failed
      Ansi.puts :green, "passed: #{name}"
    end
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
    @readline.await_readline
  end

  def input(string)
    @readline.puts(string)
  end

  def output
    @output_stream.string
  end

  def next_output
    @utput_stream.next_string
  end

  def expect_output(expected)
    if expected != output
      raise "unexpected output:\n  expected: #{expected.inspect}\n  actual:   #{output.inspect}"
    end
  end
end
