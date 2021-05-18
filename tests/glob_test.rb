require_relative 'support/test_helper'

Test.test "passing spec" do
  await_prompt
  input "rspec examples/*passing*_spec.rb"
  await_prompt
  input "exit"
  await_termination
  expect_output <<~EOF
    [1] pry(main)> rspec examples/*passing*_spec.rb
    ....

    Finished in 0 seconds (files took 0 seconds to load)
    4 examples, 0 failures

    [2] pry(main)> exit
  EOF
end
