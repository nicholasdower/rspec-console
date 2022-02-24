require_relative 'support/test_helper'

RSpec.configuration.backtrace_exclusion_patterns = [ /.*/ ]
RSpec.configuration.backtrace_inclusion_patterns = [ /examples\/passing_spec.rb/ ]

config = Tempfile.new('config')
config.write <<~EOF
  RSpec::Interactive.configure do |config|
    config.configure_rspec do
      raise 'hi'
    end
  end
EOF
config.rewind

Test.test "failing config", config_path: config.path do
  expect_failure
end

config.close
