require_relative 'support/test_helper'

Test.test "exiting via ctrl-d" do
  await_prompt
  ctrl_d
  await_termination
  # No newlines in tests because we return false from tty? in test_helper.rb.
  # In the real app, Pry will add a newline because tty? is true.
  expect_output '[1] pry(main)> '
end
