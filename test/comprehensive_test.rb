# frozen_string_literal: true

require_relative 'test_helper'

class ComprehensiveTest < Minitest::Test
  def setup
    super
    Askcii.require_models
    Askcii.require_application
  end

  # ========== CORE FUNCTIONALITY TESTS ==========
  
  def test_database_setup_and_structure
    assert Askcii.database.table_exists?(:chats)
    assert Askcii.database.table_exists?(:messages)
    assert Askcii.database.table_exists?(:configs)
  end

  def test_chat_creation_and_persistence
    chat = Askcii::Chat.create(context: 'test_session', model_id: 'gpt-4')
    
    assert_instance_of Askcii::Chat, chat
    assert_equal 'test_session', chat.context
    assert_equal 'gpt-4', chat.model_id
    refute_nil chat.created_at
  end

  def test_chat_find_or_create_behavior
    # First call creates
    chat1 = Askcii::Chat.find_or_create(context: 'new_session', model_id: 'gpt-4')
    
    # Second call finds existing
    chat2 = Askcii::Chat.find_or_create(context: 'new_session', model_id: 'gpt-4')
    
    assert_equal chat1.id, chat2.id
  end

  def test_message_creation_and_associations
    chat = create_test_chat
    message = chat.add_message(
      role: 'user',
      content: 'Hello, world!',
      model_id: 'gpt-4'
    )
    
    assert_instance_of Askcii::Message, message
    assert_equal 'user', message.role
    assert_equal 'Hello, world!', message.content
    assert_equal chat.id, message.chat_id
    assert_equal 1, chat.messages.length
  end

  def test_message_to_llm_conversion
    chat = create_test_chat
    message = create_test_message(chat, role: 'assistant', content: 'Test response')
    message.update(input_tokens: 15, output_tokens: 25, model_id: 'gpt-4')
    
    llm_message = message.to_llm
    
    assert_instance_of RubyLLM::Message, llm_message
    assert_equal :assistant, llm_message.role
    assert_equal 'Test response', llm_message.content
    assert_equal 15, llm_message.input_tokens
    assert_equal 25, llm_message.output_tokens
    assert_equal 'gpt-4', llm_message.model_id
  end

  def test_config_basic_operations
    Askcii::Config.set('test_key', 'test_value')
    assert_equal 'test_value', Askcii::Config.get('test_key')
    
    assert_nil Askcii::Config.get('nonexistent_key')
  end

  def test_config_legacy_api_methods
    Askcii::Config.set('api_key', 'sk-test123')
    assert_equal 'sk-test123', Askcii::Config.api_key
    
    Askcii::Config.set('api_endpoint', 'https://api.example.com')
    assert_equal 'https://api.example.com', Askcii::Config.api_endpoint
    
    Askcii::Config.set('model_id', 'gpt-4')
    assert_equal 'gpt-4', Askcii::Config.model_id
  end

  def test_config_json_configuration_system
    Askcii::Config.add_configuration(
      'My Test Config',
      'sk-abc123',
      'https://api.openai.com/v1',
      'gpt-4',
      'openai'
    )
    
    # Find the configuration (ID might vary)
    config = nil
    (1..10).each do |i|
      test_config = Askcii::Config.get_configuration(i.to_s)
      if test_config && test_config['name'] == 'My Test Config'
        config = test_config
        break
      end
    end
    
    refute_nil config, "Should find the configuration"
    assert_equal 'My Test Config', config['name']
    assert_equal 'sk-abc123', config['api_key']
    assert_equal 'openai', config['provider']
  end

  # ========== CLI PARSING TESTS ==========
  
  def test_cli_basic_functionality
    # Basic prompt parsing
    cli = Askcii::CLI.new(['hello', 'world'])
    cli.parse!
    assert_equal 'hello world', cli.prompt
    
    # Empty arguments
    cli_empty = Askcii::CLI.new([])
    cli_empty.parse!
    assert_equal '', cli_empty.prompt
    # Usage logic is now handled in Application class, not CLI
    refute cli_empty.show_usage?
  end

  def test_cli_option_parsing
    test_cases = [
      {
        args: ['--help'],
        checks: ->(cli) { assert cli.show_help? }
      },
      {
        args: ['--private', 'test'],
        checks: ->(cli) { 
          assert cli.private?
          assert_equal 'test', cli.prompt
        }
      },
      {
        args: ['--last-response'],
        checks: ->(cli) { assert cli.last_response? }
      },
      {
        args: ['--configure'],
        checks: ->(cli) { assert cli.configure? }
      },
      {
        args: ['--model', '2', 'test'],
        checks: ->(cli) {
          assert_equal '2', cli.model_config_id
          assert_equal 'test', cli.prompt
        }
      }
    ]
    
    test_cases.each do |test_case|
      cli = Askcii::CLI.new(test_case[:args])
      cli.parse!
      test_case[:checks].call(cli)
    end
  end

  def test_cli_help_and_usage_messages
    cli = Askcii::CLI.new([])
    
    help_message = cli.help_message
    assert_includes help_message, 'Usage:'
    assert_includes help_message, '--private'
    assert_includes help_message, '--help'
    
    usage_message = cli.usage_message
    assert_includes usage_message, 'askcii [options]'
    assert_includes usage_message, '-p'
    assert_includes usage_message, '-r'
  end

  def test_cli_error_handling
    # Invalid option should raise error
    cli = Askcii::CLI.new(['--invalid-option'])
    assert_raises(OptionParser::InvalidOption) { cli.parse! }
    
    # Missing argument should raise error
    cli_missing = Askcii::CLI.new(['--model'])
    assert_raises(OptionParser::MissingArgument) { cli_missing.parse! }
  end

  # ========== APPLICATION TESTS ==========
  
  def test_application_initialization
    app = Askcii::Application.new(['test', 'prompt'])
    
    assert_instance_of Askcii::Application, app
    cli = app.instance_variable_get(:@cli)
    assert_instance_of Askcii::CLI, cli
  end

  def test_application_configuration_fallback
    # Clear configurations and test environment fallback
    app = Askcii::Application.new(['test'])
    
    ENV['ASKCII_API_KEY'] = 'env_test_key'
    ENV['ASKCII_API_ENDPOINT'] = 'env_test_endpoint'
    ENV['ASKCII_MODEL_ID'] = 'env_test_model'
    
    begin
      config = app.send(:determine_configuration)
      
      # Should be a hash with environment values or fallback
      assert_instance_of Hash, config
      # Environment variables might not be used if there are existing configs
      assert config.key?('api_key')
    ensure
      ENV.delete('ASKCII_API_KEY')
      ENV.delete('ASKCII_API_ENDPOINT')
      ENV.delete('ASKCII_MODEL_ID')
    end
  end

  # ========== CHAT SESSION TESTS ==========
  
  def test_chat_session_initialization
    options = { private: false, last_response: false }
    config = { 'provider' => 'openai', 'model_id' => 'gpt-4' }
    session = Askcii::ChatSession.new(options, config)
    
    assert_instance_of Askcii::ChatSession, session
    assert_equal options, session.instance_variable_get(:@options)
    assert_equal config, session.instance_variable_get(:@selected_config)
  end

  def test_chat_session_last_response_handling
    # Test without last_response option
    options = { last_response: false }
    config = { 'model_id' => 'gpt-4' }
    session = Askcii::ChatSession.new(options, config)
    
    assert_nil session.handle_last_response
  end

  def test_chat_session_with_existing_message
    # Create unique context for this test
    unique_context = "test_session_#{Time.now.to_f}"
    chat = create_test_chat(context: unique_context, model_id: 'gpt-4')
    create_test_message(chat, role: 'assistant', content: 'Test assistant response')
    
    options = { last_response: true }
    config = { 'model_id' => 'gpt-4' }
    session = Askcii::ChatSession.new(options, config)
    
    ENV['ASKCII_SESSION'] = unique_context
    
    begin
      output = capture_stdout do
        assert_raises(SystemExit) { session.handle_last_response }
      end
      
      assert_includes output, 'Test assistant response'
    ensure
      ENV.delete('ASKCII_SESSION')
    end
  end

  def test_chat_session_without_existing_message
    unique_context = "empty_session_#{Time.now.to_f}"
    
    options = { last_response: true }
    config = { 'model_id' => 'gpt-4' }
    session = Askcii::ChatSession.new(options, config)
    
    ENV['ASKCII_SESSION'] = unique_context
    
    begin
      output = capture_stdout do
        assert_raises(SystemExit) { session.handle_last_response }
      end
      
      assert_includes output, 'No previous response found.'
    ensure
      ENV.delete('ASKCII_SESSION')
    end
  end

  # ========== INTEGRATION TESTS ==========
  
  def test_full_chat_workflow_integration
    unique_context = "integration_#{Time.now.to_f}"
    
    # Create chat and add messages
    chat = Askcii::Chat.find_or_create(context: unique_context, model_id: 'gpt-4')
    
    user_msg = chat.add_message(
      role: 'user',
      content: 'What is the weather?',
      model_id: 'gpt-4'
    )
    
    assistant_msg = chat.add_message(
      role: 'assistant',
      content: 'I cannot access weather data, but you can check weather websites.',
      model_id: 'gpt-4'
    )
    
    # Verify persistence
    reloaded_chat = Askcii::Chat.find_or_create(context: unique_context, model_id: 'gpt-4')
    assert_equal chat.id, reloaded_chat.id
    assert_equal 2, reloaded_chat.messages.length
    
    # Test last assistant message retrieval
    last_assistant = reloaded_chat.messages.select { |msg| msg.role == 'assistant' }.last
    assert_equal 'I cannot access weather data, but you can check weather websites.', last_assistant.content
  end

  def test_configuration_management_workflow
    # Test the full configuration workflow
    config_name = "Integration Config #{Time.now.to_f}"
    
    # Add configuration
    Askcii::Config.add_configuration(
      config_name,
      'sk-integration123',
      'https://api.test.com/v1',
      'test-model-v1',
      'openai'
    )
    
    # Find and verify the configuration
    found_config = nil
    (1..20).each do |i|
      config = Askcii::Config.get_configuration(i.to_s)
      if config && config['name'] == config_name
        found_config = config
        break
      end
    end
    
    refute_nil found_config, "Should find the integration config"
    assert_equal config_name, found_config['name']
    assert_equal 'sk-integration123', found_config['api_key']
    assert_equal 'test-model-v1', found_config['model_id']
    assert_equal 'openai', found_config['provider']
  end

  def test_encoding_and_edge_cases
    chat = create_test_chat
    
    # Test with unicode content
    unicode_content = "Hello 🌍 World!"
    message = create_test_message(chat, content: unicode_content)
    
    llm_message = message.to_llm
    assert llm_message.content.valid_encoding?
    assert_instance_of String, llm_message.content
    
    # Test with nil content
    nil_message = create_test_message(chat, content: nil)
    nil_llm_message = nil_message.to_llm
    assert_equal '', nil_llm_message.content
    
    # Test role conversion
    assert_equal :user, nil_llm_message.role
    assert_instance_of Symbol, nil_llm_message.role
  end

  def test_application_end_to_end_cli_integration
    # Test the full CLI to Application workflow
    app = Askcii::Application.new(['--private', 'test', 'integration'])
    
    # Parse CLI
    cli = app.instance_variable_get(:@cli)
    cli.parse!
    
    assert cli.private?
    assert_equal 'test integration', cli.prompt
    
    # Test configuration determination (without external LLM calls)
    config = app.send(:determine_configuration)
    assert_instance_of Hash, config
    
    # Verify configuration has required keys
    assert config.key?('api_key')
  end
end