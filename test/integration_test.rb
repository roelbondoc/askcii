# frozen_string_literal: true

require_relative 'test_helper'

class IntegrationTest < Minitest::Test
  def setup
    super
    Askcii.require_models
    Askcii.require_application

    # Set up a minimal working configuration
    @test_config = {
      'name' => 'Test Config',
      'provider' => 'openai',
      'api_key' => 'test_key',
      'api_endpoint' => 'https://api.openai.com/v1',
      'model_id' => 'gpt-4'
    }
  end

  def test_database_setup_and_models
    # Test that database tables are created
    assert Askcii.database.table_exists?(:chats)
    assert Askcii.database.table_exists?(:messages)
    assert Askcii.database.table_exists?(:configs)

    # Test model creation
    chat = Askcii::Chat.create(context: 'test', model_id: 'gpt-4')
    message = chat.add_message(role: 'user', content: 'test', model_id: 'gpt-4')

    assert_instance_of Askcii::Chat, chat
    assert_instance_of Askcii::Message, message
    assert_equal 1, chat.messages.length
  end

  def test_configuration_workflow
    # Add configuration
    Askcii::Config.add_configuration(
      @test_config['name'],
      @test_config['api_key'],
      @test_config['api_endpoint'],
      @test_config['model_id'],
      @test_config['provider']
    )

    # Set as default
    Askcii::Config.set_default_configuration('1')

    # Verify configuration
    config = Askcii::Config.current_configuration
    assert_equal @test_config['name'], config['name']
    assert_equal @test_config['provider'], config['provider']
  end

  def test_chat_persistence_workflow
    # Create a chat session
    context = 'integration_test'
    chat = Askcii::Chat.find_or_create(context: context, model_id: 'gpt-4')

    # Add user message
    chat.add_message(
      role: 'user',
      content: 'Hello, how are you?',
      model_id: 'gpt-4'
    )

    # Add assistant message
    chat.add_message(
      role: 'assistant',
      content: 'I am doing well, thank you!',
      model_id: 'gpt-4'
    )

    # Verify messages are persisted
    reloaded_chat = Askcii::Chat.find_or_create(context: context, model_id: 'gpt-4')
    assert_equal chat.id, reloaded_chat.id
    assert_equal 2, reloaded_chat.messages.length

    # Test last response functionality
    last_assistant_message = reloaded_chat.messages.select { |msg| msg.role == 'assistant' }.last
    assert_equal 'I am doing well, thank you!', last_assistant_message.content
  end

  def test_cli_parsing_integration
    # Test various CLI combinations
    test_cases = [
      {
        args: ['--help'],
        expectations: { help: true }
      },
      {
        args: ['--private', 'test', 'prompt'],
        expectations: { private: true, prompt: 'test prompt' }
      },
      {
        args: ['--model', '2', '--private', 'analyze', 'this'],
        expectations: { model_config_id: '2', private: true, prompt: 'analyze this' }
      },
      {
        args: ['--last-response'],
        expectations: { last_response: true }
      },
      {
        args: ['--configure'],
        expectations: { configure: true }
      }
    ]

    test_cases.each do |test_case|
      cli = Askcii::CLI.new(test_case[:args])
      cli.parse!

      test_case[:expectations].each do |method, expected_value|
        case method
        when :help
          assert_equal expected_value, cli.show_help?
        when :private
          assert_equal expected_value, cli.private?
        when :last_response
          assert_equal expected_value, cli.last_response?
        when :configure
          assert_equal expected_value, cli.configure?
        when :model_config_id
          assert_equal expected_value, cli.model_config_id
        when :prompt
          assert_equal expected_value, cli.prompt
        end
      end
    end
  end

  def test_error_handling_scenarios
    # Test invalid JSON in configuration
    Askcii::Config.set('config_invalid', 'invalid json')
    assert_equal [], Askcii::Config.configurations

    # Test missing configuration
    assert_nil Askcii::Config.get_configuration('999')

    # Test invalid CLI options
    cli = Askcii::CLI.new(['--invalid-option'])
    assert_raises(OptionParser::InvalidOption) do
      cli.parse!
    end

    # Test missing model argument
    cli = Askcii::CLI.new(['--model'])
    assert_raises(OptionParser::MissingArgument) do
      cli.parse!
    end
  end

  def test_environment_variable_fallback
    # Clear any existing configurations
    Askcii::Config.configurations.each do |config|
      Askcii::Config.delete_configuration(config['id'])
    end

    # Set environment variables
    ENV['ASKCII_API_KEY'] = 'env_api_key'
    ENV['ASKCII_API_ENDPOINT'] = 'env_endpoint'
    ENV['ASKCII_MODEL_ID'] = 'env_model'

    app = Askcii::Application.new(['test'])
    config = app.send(:determine_configuration)

    assert_equal 'env_api_key', config['api_key']
    assert_equal 'env_endpoint', config['api_endpoint']
    assert_equal 'env_model', config['model_id']
  ensure
    ENV.delete('ASKCII_API_KEY')
    ENV.delete('ASKCII_API_ENDPOINT')
    ENV.delete('ASKCII_MODEL_ID')
  end

  def test_unicode_and_encoding_handling
    chat = create_test_chat

    # Test various unicode content
    unicode_content = 'Hello 👋 World! Émojis and spëcial characters: 中文 العربية'
    message = create_test_message(chat, content: unicode_content)

    llm_message = message.to_llm
    assert_equal unicode_content, llm_message.content
    assert llm_message.content.valid_encoding?
  end

  def test_application_workflow_with_mocked_llm
    # Add configuration
    Askcii::Config.add_configuration(
      'Test Config',
      'test_key',
      'https://api.openai.com/v1',
      'gpt-4',
      'openai'
    )
    Askcii::Config.set_default_configuration('1')

    # Test private session
    app = Askcii::Application.new(['--private', 'test', 'prompt'])

    mock_ruby_llm_chat do |_mock_chat|
      output = capture_stdout do
        app.run
      end

      assert_includes output, 'Test response'
    end
  end

  def test_session_context_handling
    # Test with custom session
    ENV['ASKCII_SESSION'] = 'custom_session_123'

    chat1 = Askcii::Chat.find_or_create(context: 'custom_session_123', model_id: 'gpt-4')
    chat1.add_message(role: 'user', content: 'First message', model_id: 'gpt-4')

    # Create another chat with different session
    ENV['ASKCII_SESSION'] = 'different_session'
    chat2 = Askcii::Chat.find_or_create(context: 'different_session', model_id: 'gpt-4')

    refute_equal chat1.id, chat2.id
    assert_equal 1, chat1.messages.length
    assert_equal 0, chat2.messages.length
  ensure
    ENV.delete('ASKCII_SESSION')
  end

  def test_database_isolation_between_tests
    # This test verifies that each test gets a clean database
    chats_count = Askcii::Chat.count
    configs_count = Askcii::Config.count
    messages_count = Askcii::Message.count

    # Should start with empty database in each test
    assert_equal 0, chats_count
    assert_equal 0, configs_count
    assert_equal 0, messages_count
  end
end
