module RSpec
  module Interactive
    class Stdio
      def self.capture2(stdout:, stderr:)
        old_stdout, old_stderr = $stdout, $stderr
        $stdout, $stderr = stdout, stderr
        yield
      ensure
        $stdout, $stderr = old_stdout, old_stderr
      end

      def self.capture(stdout:, stderr:, on_error:)
        raise ArgumentError, 'missing block' unless block_given?

        old_stdout, old_stderr = STDOUT.dup, STDERR.dup

        IO.pipe do |stdout_read, stdout_write|
          IO.pipe do |stderr_read, stderr_write|
            STDOUT.reopen(stdout_write)
            STDERR.reopen(stderr_write)

            stdout_write.close
            stderr_write.close

            stdout_thread = Thread.new do
              while line = stdout_read.gets do
                stdout.print(line)
              end
            rescue StandardError => e
              on_error.call
            end

            stderr_thread = Thread.new do
              while line = stderr_read.gets do
                stderr.print(line)
              end
            rescue StandardError => e
              on_error.call
            end

            begin
              yield
            ensure
              # TODO: should the threads be killed here?
              STDOUT.reopen old_stdout
              STDERR.reopen old_stderr
            end

            stdout_thread.join
            stderr_thread.join
          end
        end
      end
    end
  end
end
