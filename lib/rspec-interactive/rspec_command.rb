# frozen_string_literal: true

module RSpec::Interactive
  class RSpecCommand < Pry::ClassCommand
    match 'rspec'
    description "Invoke RSpec."

    banner <<-BANNER
      Usage: rspec [arguments]

      See https://relishapp.com/rspec/rspec-core/docs/command-line.
    BANNER

    command_options(
      :keep_retval => false
    )

    def process
      RSpec::Interactive.rspec(args)
    end

    Pry::Commands.add_command(::RSpec::Interactive::RSpecCommand)
  end
end
