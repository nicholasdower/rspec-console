RSpec::Interactive.configure do |config|
  config.watch_dirs += ['lib']

  config.configure_rspec do
    sleep 5
    puts 'hi'
    sleep 1
    RSpec.configuration.formatter = :documentation
  end
end
