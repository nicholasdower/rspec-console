# RSpec Interactive

An Pry console capable of running specs.

## Installation & Configuration

Install:

```ruby
gem 'rspec-interactive'
```

Add a config file which configures RSpec and RSpec::Interactive, for instance `spec/rspec_interactive.rb`:

```ruby
load 'spec/spec_helper.rb'

RSpec::Interactive.configure do |config|
  config.watch_dirs += ["app", "lib", "config"]
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

See more examples below.

```shell
bundle exec rspec-interactive spec/rspec_interactive.rb
```

## Example Usage In This Repo

Start:

```shell
bundle exec rspec-interactive
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
