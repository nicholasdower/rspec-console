module RSpec::Interactive
  class InputCompleter < Pry::InputCompleter

    def rspec_completions(string)
      line = Readline.line_buffer
      before_current = Readline.point == string.length ? '' :  line[0..(Readline.point - string.length)]
      before_cursor = line[0..(Readline.point - 1)]

      if line.match(/^ *rspec +/)
        Dir[string + '*'].map { |filename| File.directory?(filename) ? "#{filename}/" : filename }
      elsif before_current.strip.empty? && "rspec".match(/^#{Regexp.escape(string)}/)
        ["rspec "]
      else
        nil
      end
    end

    def call(str, options = {})
      rspec_completions = rspec_completions(str)
      return rspec_completions if rspec_completions
      super
    end
  end
end
