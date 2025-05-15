# Askcii

A command-line application for interacting with LLM models in a terminal-friendly way.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'askcii'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install askcii

## Usage

```
# Basic usage
askcii 'Your prompt here'

# Pipe input
echo 'Your context text' | askcii 'Your prompt here'

# File input
askcii 'Your prompt here' < input.txt

# Set a custom session ID to maintain conversation context
ASKCII_SESSION_ID="project-research" askcii 'What did we talk about earlier?'

# Or add the following to your .bashrc or .zshrc to always start a new session
export ASKCII_SESSION=$(openssl rand -hex 16)

# Configure the API key, endpoint, and model ID
askcii -c

# Get the last response
askcii -r
```

## Configuration

You can configure your API key, endpoint, and model ID using the `-c` option:

```
$ askcii -c
Configuring askcii...
Enter API key: your_api_key_here
Enter API endpoint: http://localhost:11434/v1
Enter model ID: gemma3:12b
Configuration saved successfully!
```

Configuration settings are stored in a SQLite database located at `~/.local/share/askcii/askcii.db`.

You can also use environment variables to override the stored configuration:

```
ASKCII_API_KEY="your_api_key" askcii 'Hello!'
ASKCII_API_ENDPOINT="https://api.example.com/v1" askcii 'Hello!'
ASKCII_MODEL_ID="gpt-4" askcii 'Hello!'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
