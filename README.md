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
end
```

Update `.gitignore`

```shell
echo '.rspec_interactive_history' >> .gitignore
```

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
