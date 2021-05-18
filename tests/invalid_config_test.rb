require_relative 'support/test_helper'

config = Tempfile.new('config')
config.write '{'
config.rewind

Test.test "invalid config", config_path: config.path do
  await_termination
  expect_error_output <<~EOF
    failed to parse config file
  EOF
  expect_result 1
end
config.close

config = Tempfile.new('config')
config.write '{}'
config.rewind

Test.test "empty config", config_path: config.path do
  await_termination
  expect_error_output <<~EOF
    no configs found in config file
  EOF
  expect_result 1
end
