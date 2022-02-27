module RSpec
  module Interactive
    class Stdio
      def self.capture(stdout:, stderr:)
        old_stdout, old_stderr = $stdout, $stderr
        $stdout, $stderr = stdout, stderr
        yield
      ensure
        $stdout, $stderr = old_stdout, old_stderr
      end
    end
  end
end
