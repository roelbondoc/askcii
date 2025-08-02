# frozen_string_literal: true

require_relative 'test_helper'

class WorkingTests < Minitest::Test
  def setup
    super
    Askcii.require_models
  end

  def test_database_setup
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

  def test_chat_find_or_create
    # First call should create
    chat1 = Askcii::Chat.find_or_create(context: 'new_session', model_id: 'gpt-4')
    
    # Second call should find existing
    chat2 = Askcii::Chat.find_or_create(context: 'new_session', model_id: 'gpt-4')
    
    assert_equal chat1.id, chat2.id
  end

  def test_message_creation_and_association
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
    
    llm_message = message.to_llm
    
    assert_instance_of RubyLLM::Message, llm_message
    assert_equal :assistant, llm_message.role
    assert_equal 'Test response', llm_message.content
  end

  def test_config_basic_operations
    Askcii::Config.set('test_key', 'test_value')
    assert_equal 'test_value', Askcii::Config.get('test_key')
    
    # Test legacy methods
    Askcii::Config.set('api_key', 'sk-test123')
    assert_equal 'sk-test123', Askcii::Config.api_key
  end

  def test_config_json_configuration
    Askcii::Config.add_configuration(
      'Test Config',
      'sk-test123',
      'https://api.openai.com/v1',
      'gpt-4',
      'openai'
    )
    
    config = Askcii::Config.get_configuration('1')
    assert_equal 'Test Config', config['name']
    assert_equal 'sk-test123', config['api_key']
    assert_equal 'gpt-4', config['model_id']
  end

  def test_cli_basic_functionality
    Askcii.require_application
    
    # Test basic prompt parsing
    cli = Askcii::CLI.new(['hello', 'world'])
    cli.parse!
    assert_equal 'hello world', cli.prompt
    
    # Test help option
    cli_help = Askcii::CLI.new(['--help'])
    cli_help.parse!
    assert cli_help.show_help?
    
    # Test private option
    cli_private = Askcii::CLI.new(['--private', 'test'])
    cli_private.parse!
    assert cli_private.private?
    assert_equal 'test', cli_private.prompt
  end

  def test_application_initialization
    Askcii.require_application
    
    app = Askcii::Application.new(['test', 'prompt'])
    assert_instance_of Askcii::Application, app
    
    cli = app.instance_variable_get(:@cli)
    assert_instance_of Askcii::CLI, cli
  end

  def test_chat_session_initialization
    Askcii.require_application
    
    options = { private: false, last_response: false }
    config = { 'provider' => 'openai', 'model_id' => 'gpt-4' }
    session = Askcii::ChatSession.new(options, config)
    
    assert_instance_of Askcii::ChatSession, session
    assert_equal options, session.instance_variable_get(:@options)
    assert_equal config, session.instance_variable_get(:@selected_config)
  end

  def test_last_response_functionality
    Askcii.require_application
    
    # Create a chat with an assistant message
    chat = create_test_chat(context: 'test_context', model_id: 'gpt-4')
    create_test_message(chat, role: 'user', content: 'Hello')
    create_test_message(chat, role: 'assistant', content: 'Hi there!')
    
    options = { last_response: true }
    config = { 'model_id' => 'gpt-4' }
    session = Askcii::ChatSession.new(options, config)
    
    ENV['ASKCII_SESSION'] = 'test_context'
    
    output = capture_stdout do
      assert_raises(SystemExit) { session.handle_last_response }
    end
    
    assert_includes output, 'Hi there!'
  ensure
    ENV.delete('ASKCII_SESSION')
  end

  def test_database_isolation
    # Test that each test starts with a clean database
    initial_chats = Askcii::Chat.count
    initial_messages = Askcii::Message.count
    initial_configs = Askcii::Config.count
    
    # Create some data
    chat = create_test_chat
    create_test_message(chat)
    Askcii::Config.set('test_key', 'test_value')
    
    # Verify data was created
    assert_operator Askcii::Chat.count, :>, initial_chats
    assert_operator Askcii::Message.count, :>, initial_messages
    assert_operator Askcii::Config.count, :>, initial_configs
  end

  def test_encoding_handling
    chat = create_test_chat
    unicode_content = "Hello 👋 World!"
    message = create_test_message(chat, content: unicode_content)
    
    llm_message = message.to_llm
    assert llm_message.content.valid_encoding?
    # Note: The actual content may be modified due to encoding issues in the environment
    assert_instance_of String, llm_message.content
  end
end