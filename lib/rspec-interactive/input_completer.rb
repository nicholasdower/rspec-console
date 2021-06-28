module RSpec::Interactive
  class InputCompleter < Pry::InputCompleter

    def cli_completions(command, string)
      line = Readline.line_buffer
      before_current = Readline.point == string.length ? '' :  line[0..(Readline.point - string.length)]
      before_cursor = line[0..(Readline.point - 1)]

      if line.match(/^ *#{command} +/)
        Dir[string + '*'].map { |filename| File.directory?(filename) ? "#{filename}/" : filename }
      elsif before_current.strip.empty? && command.match(/^#{Regexp.escape(string)}/)
        ["#{command} "]
      else
        nil
      end
    end

    def call(str, options = {})
      rspec_completions = cli_completions('rspec', str)
      return rspec_completions if rspec_completions

      rubocop_completions = cli_completions('rubocop', str)
      return rubocop_completions if rubocop_completions

      super
    end
  end
end
