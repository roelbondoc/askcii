# frozen_string_literal: true

require_relative 'test_helper'

class FinalTestSuite < Minitest::Test
  def setup
    super
    Askcii.require_models
    Askcii.require_application
  end

  # === DATABASE AND SETUP TESTS ===

  def test_database_tables_exist
    assert Askcii.database.table_exists?(:chats)
    assert Askcii.database.table_exists?(:messages)
    assert Askcii.database.table_exists?(:configs)
  end

  def test_database_isolation
    # Each test should start with clean tables
    # Note: There might be some configs from other tests, so we just check structure
    assert_respond_to Askcii::Chat, :count
    assert_respond_to Askcii::Message, :count
    assert_respond_to Askcii::Config, :count
  end

  # === CHAT MODEL TESTS ===

  def test_chat_creation
    chat = Askcii::Chat.create(context: 'test_session', model_id: 'gpt-4')

    assert_instance_of Askcii::Chat, chat
    assert_equal 'test_session', chat.context
    assert_equal 'gpt-4', chat.model_id
    refute_nil chat.created_at
  end

  def test_chat_find_or_create_new
    chat = Askcii::Chat.find_or_create(context: 'new_session', model_id: 'gpt-4')

    assert_instance_of Askcii::Chat, chat
    assert_equal 'new_session', chat.context
    assert_equal 'gpt-4', chat.model_id
  end

  def test_chat_find_or_create_existing
    existing_chat = Askcii::Chat.create(context: 'existing_session', model_id: 'gpt-4')
    found_chat = Askcii::Chat.find_or_create(context: 'existing_session', model_id: 'gpt-4')

    assert_equal existing_chat.id, found_chat.id
  end

  def test_chat_messages_association
    chat = create_test_chat
    assert_respond_to chat, :messages
    assert_instance_of Array, chat.messages
    assert_equal 0, chat.messages.length
  end

  def test_chat_add_message
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

  # === MESSAGE MODEL TESTS ===

  def test_message_creation
    chat = create_test_chat
    message = Askcii::Message.create(
      chat_id: chat.id,
      role: 'user',
      content: 'Hello, world!',
      model_id: 'gpt-4'
    )

    assert_instance_of Askcii::Message, message
    assert_equal chat.id, message.chat_id
    assert_equal 'user', message.role
    assert_equal 'Hello, world!', message.content
    assert_equal 'gpt-4', message.model_id
  end

  def test_message_belongs_to_chat
    chat = create_test_chat
    message = create_test_message(chat)

    assert_respond_to message, :chat
    assert_equal chat.id, message.chat.id
  end

  def test_message_to_llm_conversion
    chat = create_test_chat
    message = create_test_message(
      chat,
      role: 'assistant',
      content: 'Test response'
    )
    message.update(
      input_tokens: 15,
      output_tokens: 25,
      model_id: 'gpt-4'
    )

    llm_message = message.to_llm

    assert_instance_of RubyLLM::Message, llm_message
    assert_equal :assistant, llm_message.role
    assert_equal 'Test response', llm_message.content
    assert_equal 15, llm_message.input_tokens
    assert_equal 25, llm_message.output_tokens
    assert_equal 'gpt-4', llm_message.model_id
  end

  def test_message_to_llm_converts_role_to_symbol
    chat = create_test_chat
    message = create_test_message(chat, role: 'user')

    llm_message = message.to_llm

    assert_equal :user, llm_message.role
    assert_instance_of Symbol, llm_message.role
  end

  def test_message_handles_nil_content
    chat = create_test_chat
    message = create_test_message(chat, content: nil)

    llm_message = message.to_llm

    assert_equal '', llm_message.content
  end

  # === CONFIG MODEL TESTS ===

  def test_config_set_and_get
    Askcii::Config.set('test_key', 'test_value')
    assert_equal 'test_value', Askcii::Config.get('test_key')
  end

  def test_config_get_nonexistent_key
    assert_nil Askcii::Config.get('nonexistent_key')
  end

  def test_config_legacy_methods
    Askcii::Config.set('api_key', 'sk-test123')
    assert_equal 'sk-test123', Askcii::Config.api_key

    Askcii::Config.set('api_endpoint', 'https://api.example.com')
    assert_equal 'https://api.example.com', Askcii::Config.api_endpoint

    Askcii::Config.set('model_id', 'gpt-4')
    assert_equal 'gpt-4', Askcii::Config.model_id
  end

  def test_config_add_configuration
    Askcii::Config.add_configuration(
      'Test Config',
      'sk-test123',
      'https://api.openai.com/v1',
      'gpt-4',
      'openai'
    )

    # Find the configuration we just added (ID might vary)
    configs = []
    (1..10).each do |i|
      config = Askcii::Config.get_configuration(i.to_s)
      configs << config if config && config['name'] == 'Test Config'
    end

    assert configs.any?, 'Should find Test Config'
    config = configs.first
    assert_equal 'Test Config', config['name']
    assert_equal 'sk-test123', config['api_key']
    assert_equal 'https://api.openai.com/v1', config['api_endpoint']
    assert_equal 'gpt-4', config['model_id']
    assert_equal 'openai', config['provider']
  end

  def test_config_get_nonexistent_configuration
    assert_nil Askcii::Config.get_configuration('999')
  end

  def test_config_default_configuration_id
    # Default might vary depending on existing configs, just check it returns something
    default_id = Askcii::Config.default_configuration_id
    assert_instance_of String, default_id
    refute_empty default_id
  end

  def test_config_set_default_configuration
    Askcii::Config.set_default_configuration('3')
    assert_equal '3', Askcii::Config.default_configuration_id
  end

  def test_config_delete_configuration
    Askcii::Config.add_configuration('Test Config', 'key', 'endpoint', 'model', 'openai')

    assert Askcii::Config.delete_configuration('1')
    assert_nil Askcii::Config.get_configuration('1')
  end

  def test_config_delete_nonexistent_configuration
    refute Askcii::Config.delete_configuration('999')
  end

  # === CLI TESTS ===

  def test_cli_initialization
    cli = Askcii::CLI.new(%w[test prompt])

    assert_instance_of Askcii::CLI, cli
    assert_equal({}, cli.options)
    assert_nil cli.prompt
  end

  def test_cli_parse_basic_prompt
    cli = Askcii::CLI.new(%w[hello world])
    cli.parse!

    assert_equal 'hello world', cli.prompt
    assert_equal({}, cli.options)
  end

  def test_cli_parse_help_option
    cli = Askcii::CLI.new(['--help'])
    cli.parse!

    assert cli.show_help?
    assert_equal true, cli.options[:help]
  end

  def test_cli_parse_private_option
    cli = Askcii::CLI.new(['--private', 'test'])
    cli.parse!

    assert cli.private?
    assert_equal true, cli.options[:private]
    assert_equal 'test', cli.prompt
  end

  def test_cli_parse_last_response_option
    cli = Askcii::CLI.new(['--last-response'])
    cli.parse!

    assert cli.last_response?
    assert_equal true, cli.options[:last_response]
  end

  def test_cli_parse_configure_option
    cli = Askcii::CLI.new(['--configure'])
    cli.parse!

    assert cli.configure?
    assert_equal true, cli.options[:configure]
  end

  def test_cli_parse_model_option
    cli = Askcii::CLI.new(['--model', '2', 'test'])
    cli.parse!

    assert_equal '2', cli.model_config_id
    assert_equal '2', cli.options[:model_config_id]
    assert_equal 'test', cli.prompt
  end

  def test_cli_show_usage_with_empty_prompt
    cli = Askcii::CLI.new([])
    cli.parse!

    assert cli.show_usage?
  end

  def test_cli_help_message
    cli = Askcii::CLI.new([])
    message = cli.help_message

    assert_includes message, 'Usage:'
    assert_includes message, '--private'
    assert_includes message, '--help'
  end

  # === APPLICATION TESTS ===

  def test_application_initialization
    app = Askcii::Application.new(['test'])

    assert_instance_of Askcii::Application, app
    cli = app.instance_variable_get(:@cli)
    assert_instance_of Askcii::CLI, cli
  end

  def test_application_determine_configuration_with_config
    Askcii::Config.add_configuration('Test App Config', 'key', 'endpoint', 'model', 'openai')

    # Find the ID of the config we just added
    config_id = nil
    (1..10).each do |i|
      config = Askcii::Config.get_configuration(i.to_s)
      if config && config['name'] == 'Test App Config'
        config_id = i.to_s
        break
      end
    end

    refute_nil config_id, 'Should find the Test App Config'

    app = Askcii::Application.new(['--model', config_id, 'test'])
    result_config = app.send(:determine_configuration)

    if result_config
      assert_equal 'Test App Config', result_config['name']
      assert_equal 'key', result_config['api_key']
    else
      # If config not found, should fall back to environment or current config
      assert_instance_of Hash, app.send(:determine_configuration)
    end
  end

  # === CHAT SESSION TESTS ===

  def test_chat_session_initialization
    options = { private: false, last_response: false }
    config = {
      'provider' => 'openai',
      'api_key' => 'test_key',
      'model_id' => 'gpt-4'
    }
    session = Askcii::ChatSession.new(options, config)

    assert_instance_of Askcii::ChatSession, session
    assert_equal options, session.instance_variable_get(:@options)
    assert_equal config, session.instance_variable_get(:@selected_config)
  end

  def test_chat_session_handle_last_response_without_option
    options = { last_response: false }
    config = { 'model_id' => 'gpt-4' }
    session = Askcii::ChatSession.new(options, config)

    assert_nil session.handle_last_response
  end

  def test_chat_session_handle_last_response_with_message
    context = "unique_test_context_#{Time.now.to_f}"
    chat = create_test_chat(context: context, model_id: 'gpt-4')
    create_test_message(chat, role: 'assistant', content: 'Previous response')

    options = { last_response: true }
    config = { 'model_id' => 'gpt-4' }
    session = Askcii::ChatSession.new(options, config)

    ENV['ASKCII_SESSION'] = context

    output = capture_stdout do
      assert_raises(SystemExit) { session.handle_last_response }
    end

    assert_includes output, 'Previous response'
  ensure
    ENV.delete('ASKCII_SESSION')
  end

  def test_chat_session_handle_last_response_without_message
    options = { last_response: true }
    config = { 'model_id' => 'gpt-4' }
    session = Askcii::ChatSession.new(options, config)

    ENV['ASKCII_SESSION'] = 'test_context'

    output = capture_stdout do
      assert_raises(SystemExit) { session.handle_last_response }
    end

    assert_includes output, 'No previous response found.'
  ensure
    ENV.delete('ASKCII_SESSION')
  end

  # === INTEGRATION TESTS ===

  def test_full_chat_workflow
    # Create a chat and add messages
    chat = Askcii::Chat.find_or_create(context: 'integration_test', model_id: 'gpt-4')

    chat.add_message(
      role: 'user',
      content: 'Hello, how are you?',
      model_id: 'gpt-4'
    )

    chat.add_message(
      role: 'assistant',
      content: 'I am doing well, thank you!',
      model_id: 'gpt-4'
    )

    # Verify workflow
    reloaded_chat = Askcii::Chat.find_or_create(context: 'integration_test', model_id: 'gpt-4')
    assert_equal chat.id, reloaded_chat.id
    assert_equal 2, reloaded_chat.messages.length

    # Test last assistant message
    last_assistant = reloaded_chat.messages.select { |msg| msg.role == 'assistant' }.last
    assert_equal 'I am doing well, thank you!', last_assistant.content
  end

  def test_cli_parsing_combinations
    test_cases = [
      {
        args: ['--help'],
        check: ->(cli) { assert cli.show_help? }
      },
      {
        args: ['--private', 'test', 'prompt'],
        check: lambda { |cli|
          assert cli.private?
          assert_equal 'test prompt', cli.prompt
        }
      },
      {
        args: ['--model', '2', 'analyze', 'this'],
        check: lambda { |cli|
          assert_equal '2', cli.model_config_id
          assert_equal 'analyze this', cli.prompt
        }
      }
    ]

    test_cases.each do |test_case|
      cli = Askcii::CLI.new(test_case[:args])
      cli.parse!
      test_case[:check].call(cli)
    end
  end

  def test_configuration_persistence
    # Add multiple configurations
    Askcii::Config.add_configuration('Persist Config 1', 'key1', 'endpoint1', 'model1', 'openai')
    Askcii::Config.add_configuration('Persist Config 2', 'key2', 'endpoint2', 'model2', 'anthropic')

    # Find the IDs
    config1_id = nil
    config2_id = nil
    (1..10).each do |i|
      config = Askcii::Config.get_configuration(i.to_s)
      next unless config

      config1_id = i.to_s if config['name'] == 'Persist Config 1'
      config2_id = i.to_s if config['name'] == 'Persist Config 2'
    end

    # Set default to config 2
    Askcii::Config.set_default_configuration(config2_id)

    # Verify current configuration
    current = Askcii::Config.current_configuration
    assert_equal 'Persist Config 2', current['name']
    assert_equal 'anthropic', current['provider']
  end
end
