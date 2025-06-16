# Askcii

A command-line application for interacting with multiple LLM providers in a terminal-friendly way. Supports OpenAI, Anthropic, Gemini, DeepSeek, OpenRouter, and Ollama with multi-configuration management.

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

### Basic Usage

```bash
# Basic usage
askcii 'Your prompt here'

# Pipe input from other commands
echo 'Your context text' | askcii 'Analyze this text'

# File input
askcii 'Summarize this document' < document.txt

# Private session (no conversation history saved)
askcii -p 'Tell me a joke'

# Get the last response from your current session
askcii -r

# Use a specific configuration
askcii -m 2 'Hello using configuration 2'
```

### Session Management

```bash
# Set a custom session ID to maintain conversation context
ASKCII_SESSION="project-research" askcii 'What did we talk about earlier?'

# Generate a new session for each terminal session
export ASKCII_SESSION=$(openssl rand -hex 16)
```

### Command Line Options

```
Usage: askcii [options] 'Your prompt here'

Options:
  -p, --private         Start a private session and do not record
  -r, --last-response   Output the last response
  -c, --configure       Manage configurations
  -m, --model ID        Use specific configuration ID
  -h, --help            Show help
```

## Configuration Management

Askcii supports multi-configuration management, allowing you to easily switch between different LLM providers and models.

### Interactive Configuration

Use the `-c` flag to access the configuration management interface:

```bash
askcii -c
```

This will show you a menu like:

```
Configuration Management
=======================
Current configurations:
  1. GPT-4 [openai] (default)
  2. Claude Sonnet [anthropic]
  3. Gemini Pro [gemini]
  4. Local Llama [ollama]

Options:
  1. Add new configuration
  2. Set default configuration
  3. Delete configuration
  4. Exit
```

### Supported Providers

1. **OpenAI** - GPT models (gpt-4, gpt-3.5-turbo, etc.)
2. **Anthropic** - Claude models (claude-3-sonnet, claude-3-haiku, etc.)
3. **Gemini** - Google's Gemini models
4. **DeepSeek** - DeepSeek models
5. **OpenRouter** - Access to multiple models through OpenRouter
6. **Ollama** - Local models (no API key required)

### Adding a New Configuration

When adding a configuration, you'll be prompted for:

1. **Configuration name** - A friendly name for this configuration
2. **Provider** - Choose from the supported providers
3. **API key** - Your API key for the provider (not needed for Ollama)
4. **API endpoint** - The API endpoint (defaults provided for each provider)
5. **Model ID** - The specific model to use

Example for OpenAI:
```
Enter configuration name: GPT-4 Turbo
Provider (1-6): 1
Enter OpenAI API key: sk-your-api-key-here
Enter API endpoint (default: https://api.openai.com/v1): [press enter for default]
Enter model ID: gpt-4-turbo-preview
```

Example for Ollama (local):
```
Enter configuration name: Local Llama
Provider (1-6): 6
Enter API endpoint (default: http://localhost:11434/v1): [press enter for default]
Enter model ID: llama3:8b
```

### Using Configurations

```bash
# Use the default configuration
askcii 'Hello world'

# Use a specific configuration by ID
askcii -m 2 'Hello using configuration 2'

# List all configurations
askcii -c
```

### Configuration Storage

Configuration settings are stored in a SQLite database located at `~/.local/share/askcii/askcii.db`.

### Environment Variable Fallback

You can still use environment variables as a fallback when no configurations are set up:

```bash
ASKCII_API_KEY="your_api_key" askcii 'Hello!'
ASKCII_API_ENDPOINT="https://api.example.com/v1" askcii 'Hello!'
ASKCII_MODEL_ID="gpt-4" askcii 'Hello!'
```

## Examples

### Daily Workflow Examples

```bash
# Code review
git diff | askcii 'Review this code change and suggest improvements'

# Log analysis
tail -100 /var/log/app.log | askcii 'Summarize any errors or issues'

# Documentation
askcii 'Explain how to set up a Redis cluster' > redis-setup.md

# Quick calculations
askcii 'Calculate compound interest: $1000 at 5% for 10 years'

# Text processing
cat customers.csv | askcii 'Convert this CSV to JSON format'
```

### Multi-Provider Usage

```bash
# Use Claude for creative writing
askcii -m 1 'Write a short story about AI'

# Use GPT-4 for code analysis
askcii -m 2 'Explain this Python function' < function.py

# Use local Ollama for private data
askcii -m 3 -p 'Analyze this sensitive document' < confidential.txt
```

## Session Management

Askcii maintains conversation history unless you use the private mode (`-p`). Sessions are identified by:

1. The `ASKCII_SESSION` environment variable
2. A randomly generated session ID if not specified

```bash
# Start a named session for a project
export ASKCII_SESSION="project-alpha"
askcii 'What is the project timeline?'
askcii 'What are the main risks?' # This will have context from previous question

# Use private mode for one-off questions
askcii -p 'What is the weather like?'

# Get the last response from current session
askcii -r
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
