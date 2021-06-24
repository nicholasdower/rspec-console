# RSpec Interactive

An Pry console capable of running specs.

## Installation & Configuration

Install:

```ruby
gem 'rspec-interactive'
```

Add a config file which configures RSpec and RSpec::Interactive, for example `spec/rspec_interactive.rb`:

```ruby
RSpec::Interactive.configure do |config|
  # Directories to watch for file changes. When a file changes, it will be reloaded like `load 'path/to/file'`.
  config.watch_dirs += ["app", "lib", "config"]

  # This block is invoked on startup. RSpec configuration must happen here so that it can be reloaded before each test run.
  config.configure_rspec do
    require './spec/spec_helper.rb'
  end

  # Invoked whenever a class is loaded due to a file change in one of the watch_dirs.
  config.on_class_load do |clazz|
    clazz.clear_validators! if clazz < ApplicationRecord
  end

  # Invoked before each invocation of RSpec. Can also be manually invoked by typing `refresh` in the console.
  # Any modified/added files will be loaded via `load` before invoking.
  config.refresh do
    FactoryBot.reload
    Rails.application.reloader.reload!
  end
end
```

Update `.gitignore`

```shell
echo '.rspec_interactive_history' >> .gitignore
```

### A Note About FactoryBot

It is not possible to reload a file containing FactoryBot factory definitions via `load` because FactoryBot does not allow factories to be redefined. Be carefule not to add any directories to `watch_dirs` which contain factory definitions. Instead, you should configure the location of your factories like the following in your `spec_helper.rb`:

```ruby
FactoryBot.definition_file_paths = %w(spec/factories)
FactoryBot.find_definitions
```

Then add the following to your RSpec Interactive config

```ruby
RSpec::Interactive.configure do |config|
  config.refresh do
    FactoryBot.reload
  end
end
```

This will cause factories to be reloaded before each test run and also whenever the `refresh` command is invoked in the console.

## Usage

Optionally, specify a config file with `--config <config-file>`. Optionally, specify arguments to an initial RSpec invocation with `--initial-rspec-args <initial-rspec-args>`.

```shell
bundle exec rspec-interactive [--config <config-file>] [--initial-rspec-args <initial-rspec-args>]
```

## Example Usage In This Repo

Start:

```shell
bundle exec rspec-interactive
```

Start with an initial RSpec invocation:

```shell
bundle exec rspec-interactive --initial-rspec-args examples/passing_spec.rb
```

Run a passing spec:

```shell
[1] pry(main)> rspec examples/passing_spec.rb
```

Run a failing spec:

```shell
[3] pry(main)> rspec examples/failing_spec.rb
```

Run an example group:

```shell
[5] pry(main)> rspec examples/passing_spec.rb:4
```

Run multiple specs:

```shell
[6] pry(main)> rspec examples/passing_spec.rb examples/failing_spec.rb
```
Debug a spec (use `exit` to resume while debugging):

```shell
[7] pry(main)> rspec examples/debugged_spec.rb
```

Run multiple specs using globbing (use `exit` to resume while debugging):

```shell
[8] pry(main)> rspec examples/*_spec.rb
```

Exit:

```shell
[9] pry(main)> exit
```

## Running Tests

```shell
bundle exec bin/test
```

## Releasing

```shell
./scripts/release.sh <version>
```
