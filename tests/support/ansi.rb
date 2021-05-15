module Ansi
  @ansi_colors = {
    :black        => '0;30',
    :red          => '0;31',
    :green        => '0;32',
    :orange       => '0;33',
    :blue         => '0;34',
    :purple       => '0;35',
    :cyan         => '0;36',
    :light_gray   => '0;37',
    :dark_gray    => '1;30',
    :light_red    => '1;31',
    :light_green  => '1;32',
    :yellow       => '1;33',
    :light_blue   => '1;34',
    :light_purple => '1;35',
    :light_cyan   => '1;36',
    :white        => '1;37'
  }

  def self.puts(color, string, output = STDOUT)
    raise "invalid color: #{color}" unless @ansi_colors[color]
    string = "" if string == nil
    output.puts "\033[#{@ansi_colors[color]}m#{string}\033[0m"
  end

  def self.print(color, string, output = STDOUT)
    raise "invalid color: #{color}" unless @ansi_colors[color]
    return unless string
    output.print "\033[#{@ansi_colors[color]}m#{string}\033[0m"
  end
end
