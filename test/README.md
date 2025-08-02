# Askcii Test Suite

This directory contains a comprehensive test suite for the Askcii command line application using Minitest.

## Structure

```
test/
├── test_helper.rb           # Test setup and helper methods
├── simple_test.rb           # Basic functionality tests
├── models/                  # Model tests
│   ├── chat_test.rb        # Chat model tests
│   ├── message_test.rb     # Message model tests
│   └── config_test.rb      # Config model tests
├── application_test.rb      # Application class tests
├── chat_session_test.rb     # ChatSession class tests
├── cli_test.rb             # CLI parsing tests
├── integration_test.rb     # Full integration tests
└── error_scenarios_test.rb  # Error handling tests
```

## Running Tests

### Run all tests
```bash
bundle exec rake test
```

### Run a specific test file
```bash
bundle exec ruby test/simple_test.rb
bundle exec ruby test/models/chat_test.rb
```

### Run tests with verbose output
```bash
bundle exec rake test TESTOPTS="-v"
```

## Test Features

### Test Isolation
- Each test gets a fresh temporary database
- Environment variables are restored after each test
- Database connections are properly cleaned up

### Helper Methods
- `create_test_chat(context:, model_id:)` - Creates a test chat
- `create_test_message(chat, role:, content:)` - Creates a test message
- `capture_stdout` - Captures stdout for testing output
- `capture_stderr` - Captures stderr for testing errors
- `with_stdin(input)` - Mocks stdin input
- `mock_ruby_llm_chat` - Mocks RubyLLM chat interactions

### Test Coverage

#### Models
- **Chat**: Creation, associations, persistence, LLM conversion
- **Message**: Creation, encoding handling, LLM conversion
- **Config**: CRUD operations, JSON handling, multi-configuration support

#### Application Logic
- **CLI**: Option parsing, help messages, argument handling
- **Application**: Configuration determination, workflow orchestration
- **ChatSession**: Private/persistent sessions, LLM interaction

#### Integration
- End-to-end CLI workflows
- Database persistence
- Configuration management
- Error scenarios and edge cases

#### Error Handling
- Invalid JSON configurations
- Database connection errors
- Invalid CLI arguments
- Unicode and encoding issues
- Missing dependencies

## Dependencies

The test suite requires these additional gems:
- `minitest` - Testing framework
- `csv` - Required by amalgalite
- `ostruct` - For creating test objects

These are automatically installed with `bundle install`.

## Test Configuration

Tests use environment variable `ASKCII_LOG_LEVEL=ERROR` to suppress logging during test runs.

The test helper automatically:
- Sets up temporary databases for each test
- Mocks external LLM API calls
- Provides isolation between test cases
- Handles cleanup of temporary files

## Writing New Tests

When adding new tests:

1. Extend existing test files for related functionality
2. Use the helper methods for common operations
3. Follow the existing naming conventions
4. Add both success and error scenarios
5. Mock external dependencies appropriately

Example test:

```ruby
def test_new_feature
  # Setup
  chat = create_test_chat
  
  # Exercise
  result = chat.new_method('test_input')
  
  # Verify
  assert_equal 'expected_output', result
  assert_instance_of ExpectedClass, result
end
```