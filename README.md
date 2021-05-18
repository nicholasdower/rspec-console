# RSpec Interactive

An Pry console capable of running specs.

## Installation & Configuration

Install:

```ruby
gem 'rspec-interactive'
```

Add a config file named `.rspec_interactive_config`:

```json
{
 "configs": [
   {
     "name": "spec",
     "watch_dirs": ["app"],
     "init_script": "spec/spec_helper.rb"
   },
   {
     "name": "spec_integration",
     "watch_dirs": ["app"],
     "init_script": "spec_integration/integration_helper.rb"
   }
 ]
}
```

Update `.gitignore`

```shell
echo '.rspec_interactive_history' >> .gitignore
```

## Usage

See more examples below.

```shell
bundle exec rspec-interactive [spec name]
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
