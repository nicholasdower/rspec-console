# Copied from https://github.com/nviennot/rspec-console/blob/master/lib/rspec-console/config_cache.rb
class RSpecInteractive::ConfigCache
  # We have to reset the RSpec.configuration, because it contains a lot of
  # information related to the current test (what's running, what are the
  # different test results, etc).
  #
  # RSpec.configuration gets also loaded with a bunch of stuff from the
  # 'spec/spec_helper.rb' file. Often that instance is extended with other
  # modules (FactoryGirl, Mocha,...) and we don't want to replace requires with
  # load all around the place.
  #
  # Instead, we proxy and record whatever is done to RSpec.configuration during
  # the first invocation of require('spec_helper').  This is done by interposing
  # the RecordingProxy class on of RSpec.configuration.
  attr_accessor :config_proxy, :root_shared_examples

  class RecordingProxy < Struct.new(:target, :recorded_messages)
    [:include, :extend].each do |method|
      define_method(method) do |*args|
        method_missing(method, *args)
      end
    end

    def method_missing(method, *args, &block)
      self.recorded_messages << [method, args, block]
      self.target.send(method, *args, &block)
    end
  end

  def record_configuration(&configuration_block)
    ensure_configuration_setter!

    original_config = ::RSpec.configuration
    ::RSpec.configuration = RecordingProxy.new(original_config, [])

    configuration_block.call # spec helper is called during this yield, see #reset

    self.config_proxy = ::RSpec.configuration
    ::RSpec.configuration = original_config

    stash_shared_examples

    forward_rspec_config_singleton_to(self.config_proxy)
  end

  def replay_configuration
    ::RSpec.configure do |config|
      self.config_proxy.recorded_messages.each do |method, args, block|
        # reporter caches config.output_stream which is not good as it
        # prevents the runner to use a custom stdout.
        next if method == :reporter
        config.send(method, *args, &block)
      end
    end

    restore_shared_examples

    forward_rspec_config_singleton_to(self.config_proxy)
  end

  def has_recorded_config?
    !!self.config_proxy
  end

  def forward_rspec_config_singleton_to(config_proxy)
    # an old version of rspec-rails/lib/rspec/rails/view_rendering.rb adds
    # methods on the configuration singleton. This takes care of that.
    ::RSpec.configuration.singleton_class
      .send(:define_method, :method_missing, &config_proxy.method(:send))
  end

  def stash_shared_examples
    self.root_shared_examples = ::RSpec.world.shared_example_group_registry.send(:shared_example_groups).dup
  end

  def restore_shared_examples
    shared_example_groups = ::RSpec.world.shared_example_group_registry.send(:shared_example_groups)
    shared_example_groups.clear

    self.root_shared_examples.each do |context, hash|
      hash.each do |name, shared_module|
        shared_example_groups[context][name] = shared_module
      end
    end
  end

  def ensure_configuration_setter!
    return if RSpec.respond_to?(:configuration=)

    ::RSpec.instance_eval do
      def self.configuration=(value)
        @configuration = value
      end
    end
  end
end
