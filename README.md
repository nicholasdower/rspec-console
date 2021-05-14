# RSpec Interactive

**WARNING: New (or maybe old by now), experimental, untested and poorly documented. Use at your own risk.**

An interactive console used to run rspec. Also consider using [rspec-console](https://github.com/nviennot/rspec-console). It is a more mature alternative which didn't happen to work for me.

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
     "init_script": "spec/spec_helper.rb"
   },
   {
     "name": "spec_integration",
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

Start:

```shell
bundle exec rspec-interactive spec
# or
bundle exec rspec-interactive spec_integration
```

See help:

```shell
> help
```

Run a spec:

```shell
> rspec spec/foo/foo_spec.rb
```
