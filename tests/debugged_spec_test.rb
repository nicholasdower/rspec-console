require_relative 'support/test_helper'

Test.test "debugged spec" do
  await_prompt
  input "rspec examples/debugged_spec.rb"
  await_prompt
  input "exit"
  await_prompt
  input "exit"
  await_termination
  expect_output <<~EOF
    [1] pry(main)> rspec examples/debugged_spec.rb

    From: /Users/nickdower/Development/rspec-interactive/examples/debugged_spec.rb:6 :

        1: require 'rspec/core'
        2: require 'pry'
        3: 
        4: describe "example spec" do
        5:   it "gets debugged" do
     => 6:     binding.pry
        7:     expect(true).to eq(true)
        8:   end
        9: end

    [1] pry(#<RSpec::ExampleGroups::ExampleSpec>)> exit
    .

    Finished in 0 seconds (files took 0 seconds to load)
    1 example, 0 failures

    [2] pry(main)> exit
  EOF

  expect_history <<~EOF
    rspec examples/debugged_spec.rb
  EOF
end
