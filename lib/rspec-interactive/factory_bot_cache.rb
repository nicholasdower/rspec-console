module FactoryBotProxy
  @test_thread = Thread.current
  @recorded_calls = []
  @recording = false
  @in_recorded_call = false
  @log_level = :off
  @installed = false

  def self.set_log_level(level)
    check_thread
    raise "unexpected log level: #{level}, expected: :off or :debug" unless [:off, :debug].include?(level)
    @log_level = level
  end

  def self.start_recording
    check_thread
    install
    raise "alredy recording" if @recording
    log "start recording"
    @recording = true
  end

  def self.stop_recording
    check_thread
    check_installed
    raise "not recording" unless @recording
    log "stopped recording"
    @recording = false
  end

  def self.reload_and_replay
    check_thread
    check_installed
    raise "can't reload while recording" if @recording
    log "reloading FactoryBot"
    FactoryBot.reload
    return false unless !@recorded_calls&.empty?

    log "replaying FactoryBotProxy"
    @recorded_calls.map do |call|
      log "invoking: #{call[0].name}"
      call[0].call(*call[1], &call[2])
    end

    true
  end

  def self.install
    check_thread
    return if @installed

    raise "FactoryBot not initialized" if !defined?(FactoryBot)

    log "installing FactoryBotProxy"

    FactoryBot.singleton_methods.map do |method_name|
      method = FactoryBot.method(method_name)

      log "defining: FactoryBot.#{method_name}"
      FactoryBotProxy.define_method(method_name) do |*args, &block|
        FactoryBotProxy.method_body(method, args, block)
      end
    end
    FactoryBot.singleton_class.prepend(FactoryBotProxy)
    @installed = true
  end

  def self.method_body(method, args, block)
    check_thread

    method_name = method.name

    if @recording && !@in_recorded_call
      log "recording: #{method_name}"
      @in_recorded_call = true
      method.call(*args, &block)
      @in_recorded_call = false
      @recorded_calls << [method, args, block]
    else
      method.call(*args, &block)
    end
  end
  private

  def self.log(message)
    puts "FactoryBotProxy: #{message}" if @log_level == :debug
  end

  def self.check_thread
    raise "FactoryBot accessed on unexpected thread" unless Thread.current == @test_thread
  end

  def self.check_installed
    raise "FactoryBotProxy not installed. Run FactoryBotProxy.install first." unless @installed
  end
end

