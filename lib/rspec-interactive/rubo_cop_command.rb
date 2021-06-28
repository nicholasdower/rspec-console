# frozen_string_literal: true

module RSpec::Interactive
  class RuboCopCommand < Pry::ClassCommand
    match 'rubocop'
    description "Invoke RuboCop."

    banner <<-BANNER
      Usage: rubocop [arguments]

      See https://docs.rubocop.org/rubocop/usage/basic_usage.html
    BANNER

    command_options(
      :keep_retval => false
    )

    def process
      RSpec::Interactive.rubo_cop(args)
    end

    Pry::Commands.add_command(::RSpec::Interactive::RuboCopCommand)
  end
end
