# frozen_string_literal: true

module RSpec::Interactive
  class RefreshCommand < Pry::ClassCommand
    match 'refresh'
    description "Load any files in watched directories which have changed since the last refresh or rspec invocation."

    banner <<-BANNER
      Usage: refresh
    BANNER

    command_options(
      :keep_retval => false
    )

    def process
      RSpec::Interactive.refresh
    end

    Pry::Commands.add_command(::RSpec::Interactive::RefreshCommand)
  end
end
