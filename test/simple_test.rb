# frozen_string_literal: true

require_relative 'test_helper'

class SimpleTest < Minitest::Test
  def test_database_setup
    Askcii.require_models
    
    assert Askcii.database.table_exists?(:chats)
    assert Askcii.database.table_exists?(:messages)
    assert Askcii.database.table_exists?(:configs)
  end

  def test_chat_creation
    Askcii.require_models
    
    chat = Askcii::Chat.create(context: 'test', model_id: 'gpt-4')
    assert_instance_of Askcii::Chat, chat
    assert_equal 'test', chat.context
    assert_equal 'gpt-4', chat.model_id
  end

  def test_message_creation
    Askcii.require_models
    
    chat = create_test_chat
    message = create_test_message(chat)
    
    assert_instance_of Askcii::Message, message
    assert_equal chat.id, message.chat_id
  end

  def test_config_basic_operations
    Askcii.require_models
    
    Askcii::Config.set('test_key', 'test_value')
    assert_equal 'test_value', Askcii::Config.get('test_key')
  end

  def test_cli_basic_parsing
    Askcii.require_application
    
    cli = Askcii::CLI.new(['hello', 'world'])
    cli.parse!
    
    assert_equal 'hello world', cli.prompt
  end

  def test_cli_help_option
    Askcii.require_application
    
    cli = Askcii::CLI.new(['--help'])
    cli.parse!
    
    assert cli.show_help?
  end

  def test_application_initialization
    Askcii.require_application
    
    app = Askcii::Application.new(['test'])
    assert_instance_of Askcii::Application, app
  end

  def test_chat_session_initialization
    Askcii.require_application
    
    options = { private: false }
    config = { 'provider' => 'openai', 'model_id' => 'gpt-4' }
    session = Askcii::ChatSession.new(options, config)
    
    assert_instance_of Askcii::ChatSession, session
  end
end