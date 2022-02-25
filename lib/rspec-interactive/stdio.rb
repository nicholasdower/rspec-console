module RSpec
  module Interactive
    class Stdio
      def self.capture(output)
        raise ArgumentError, 'missing block' unless block_given?

        stdout, stderr = STDOUT.dup, STDERR.dup

        IO.pipe do |stdout_read, stdout_write|
          IO.pipe do |stderr_read, stderr_write|
            STDOUT.reopen(stdout_write)
            STDERR.reopen(stderr_write)

            stdout_write.close
            stderr_write.close

            thread = Thread.new do
              until stdout_read.eof? && stderr_read.eof? do
                line = stdout_read.gets
                output.puts line if line
                line = stderr_read.gets
                output.puts if line
              end
            end

            begin
              yield
            ensure
              STDOUT.reopen stdout
              STDERR.reopen stderr
            end

            thread.join
          end
        end
      end
    end
  end
end
