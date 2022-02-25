RSpec::Interactive.configure do |config|
  config.watch_dirs += ['lib']

  config.configure_rspec do
    RSpec.configuration.formatter = :documentation
  end
end
