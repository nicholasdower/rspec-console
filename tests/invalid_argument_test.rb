require_relative 'support/test_helper'

config = Tempfile.new('config')
config.write <<~EOF
  {
    "configs": [
      {
        "name": "some_config"
      }
    ]
  }
EOF
config.rewind

Test.test "unknown config name specified", args: ['some_other_config'], config_path: config.path do
  await_termination
  expect_error_output <<~EOF
    invalid config: some_other_config
  EOF
  expect_result 1
end
config.close

Test.test "config name specified without config", args: ['some_config'] do
  await_termination
  expect_error_output <<~EOF
    invalid config: some_config
  EOF
  expect_result 1
end

config = Tempfile.new('config')
config.write <<~EOF
  {
    "configs": [
      {
        "name": "some_config"
      },
      {
        "name": "some_other_config"
      }
    ]
  }
EOF
config.rewind

Test.test "no config specified when multiple exist", args: [], config_path: config.path do
  await_termination
  expect_error_output <<~EOF
    multiple configurations found, you must specify which to use
  EOF
  expect_result 1
end
