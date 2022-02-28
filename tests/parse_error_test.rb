require_relative 'support/test_helper'

Test.test "parse error" do
  await_prompt
  input "rspec --foo"
  await_prompt
  input "exit"
  await_termination
  expect_equal "output", output.gsub(/^from .*lib\/rspec-interactive/, 'from [...]'), <<~EOF
    [1] pry(main)> rspec --foo
    ParseError: invalid option: --foo

    Please use --help for a listing of valid options
    from [...]/rspec_core_parser.rb:19:in `abort'
    [1] pry(main)> exit
  EOF
end
