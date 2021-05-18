require_relative 'support/test_helper'

Test.test "passing spec" do
  await_prompt
  input "rspec examples/passing_spec.rb"
  await_prompt
  input "exit"
  await_termination
  expect_output <<~EOF
    [1] pry(main)> rspec examples/passing_spec.rb
    ..

    Finished in 0 seconds (files took 0 seconds to load)
    2 examples, 0 failures

    => <RSpec::Interactive::Result @success=true, @group_results=[...]>
    [2] pry(main)> exit
  EOF
end
