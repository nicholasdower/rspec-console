require 'shellwords'
require 'socket'

server = TCPSocket.open('localhost', 5678)
server.puts ARGV.map{|arg| Shellwords.escape arg}.join(' ')
while response = server.gets do
  puts "response: #{response}"
end
server.close
