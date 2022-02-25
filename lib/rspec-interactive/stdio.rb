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

            stdout_thread = Thread.new do
              while line = stdout_read.gets do
                output.print(line)
              end
            end

            stderr_thread = Thread.new do
              while line = stderr_read.gets do
                output.print(line)
              end
            end

            begin
              yield
            ensure
              # TODO: should the threads be killed here?
              STDOUT.reopen stdout
              STDERR.reopen stderr
            end

            stdout_thread.join
            stderr_thread.join
          end
        end
      end
    end
  end
end
