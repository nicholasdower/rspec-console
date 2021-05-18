require_relative 'support/test_helper'

Test.test "running example group at line number" do
  await_prompt
  input "rspec examples/passing_spec.rb:8"
  await_prompt
  input "exit"
  await_termination
  expect_output <<~EOF
    [1] pry(main)> rspec examples/passing_spec.rb:8
    Run options: include {:locations=>{"./examples/passing_spec.rb"=>[8]}}
    .

    Finished in 0 seconds (files took 0 seconds to load)
    1 example, 0 failures

    [2] pry(main)> exit
  EOF
end
