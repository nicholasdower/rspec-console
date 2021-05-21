require_relative 'support/test_helper'

RSpec.configuration.backtrace_exclusion_patterns = [ /.*/ ]
RSpec.configuration.backtrace_inclusion_patterns = [ /`load_spec_files'/ ]

Test.test "spec with syntax error" do
  await_prompt
  input "rspec examples/spec_with_syntax_error.rb"
  await_prompt
  input "exit"
  await_termination
  expect_equal "output", output.gsub(/.+(?=(\\|\/)[a-z_-]+[.]rb:[0-9]+:.*)/, '  [...]'), <<~EOF
    [1] pry(main)> rspec examples/spec_with_syntax_error.rb

    An error occurred while loading ./examples/spec_with_syntax_error.rb.
    Failure/Error: ::RSpec.configuration.load_spec_files

    SyntaxError:
      [...]/spec_with_syntax_error.rb:5: unterminated string meets end of file
      [...]/spec_with_syntax_error.rb:5: syntax error, unexpected end-of-input, expecting `end'
      [...]/configuration.rb:1607:in `load_spec_files'
    No examples found.


    Finished in 0 seconds (files took 0 seconds to load)
    0 examples, 0 failures, 1 error occurred outside of examples

    [2] pry(main)> exit
  EOF
end
