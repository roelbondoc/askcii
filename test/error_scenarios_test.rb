# frozen_string_literal: true

require_relative 'test_helper'

class ErrorScenariosTest < Minitest::Test
  def setup
    super
    Askcii.require_models
    Askcii.require_application
  end

  def test_database_connection_errors
    # Test graceful handling when database path is not writable
    original_method = Askcii.method(:db_path)
    
    Askcii.define_singleton_method(:db_path) { '/invalid/path/test.db' }
    
    assert_raises(Sequel::DatabaseConnectionError) do
      Askcii.database
    end
  ensure
    Askcii.define_singleton_method(:db_path, original_method)
  end

  def test_invalid_configuration_handling
    # Test with completely invalid JSON
    Askcii::Config.set('config_1', '{invalid json}')
    
    assert_nil Askcii::Config.get_configuration('1')
    assert_equal [], Askcii::Config.configurations
  end

  def test_missing_required_fields_in_configuration
    # Test configuration with missing fields
    incomplete_config = {
      'name' => 'Incomplete Config'
      # Missing api_key, model_id, etc.
    }
    
    Askcii::Config.set('config_1', incomplete_config.to_json)
    config = Askcii::Config.get_configuration('1')
    
    assert_nil config['api_key']
    assert_nil config['model_id']
    assert_equal 'Incomplete Config', config['name']
  end

  def test_chat_session_with_missing_configuration
    options = { last_response: true }
    chat_session = Askcii::ChatSession.new(options, nil)
    
    # Should handle nil configuration gracefully
    assert_raises(NoMethodError) do
      chat_session.send(:create_private_chat)
    end
  end

  def test_message_with_invalid_encoding
    chat = create_test_chat
    
    # Create message with invalid UTF-8 sequence
    invalid_content = "Hello\xFF\xFEWorld".dup.force_encoding('UTF-8')
    message = create_test_message(chat, content: invalid_content)
    
    # Should handle encoding issues gracefully
    llm_message = message.to_llm
    assert llm_message.content.valid_encoding?
    refute_equal invalid_content, llm_message.content
  end

  def test_application_with_invalid_model_config_id
    app = Askcii::Application.new(['--model', '999', 'test'])
    
    # Should fall back to current configuration when model ID doesn't exist
    config = app.send(:determine_configuration)
    
    # Should return environment variable fallback
    assert_instance_of Hash, config
  end

  def test_cli_parsing_edge_cases
    # Test with empty model ID
    cli = Askcii::CLI.new(['--model', '', 'test'])
    cli.parse!
    
    assert_equal '', cli.model_config_id
    
    # Test with special characters in prompt
    cli = Askcii::CLI.new(['test', 'with', '$pecial', '&', 'characters'])
    cli.parse!
    
    assert_equal 'test with $pecial & characters', cli.prompt
  end

  def test_chat_creation_errors
    # Test creating chat with invalid parameters
    assert_raises(Sequel::ValidationFailed, Sequel::DatabaseError) do
      Askcii::Chat.create(context: nil, model_id: nil)
    end
  end

  def test_message_creation_errors
    chat = create_test_chat
    
    # Test creating message with invalid chat_id
    assert_raises(Sequel::ForeignKeyConstraintViolation) do
      Askcii::Message.create(
        chat_id: 99999,  # Non-existent chat
        role: 'user',
        content: 'test'
      )
    end
  end

  def test_configuration_deletion_edge_cases
    # Test deleting non-existent configuration
    result = Askcii::Config.delete_configuration('999')
    refute result
    
    # Test deleting when it's the only configuration
    Askcii::Config.add_configuration('Only Config', 'key', 'endpoint', 'model', 'openai')
    Askcii::Config.set_default_configuration('1')
    
    assert Askcii::Config.delete_configuration('1')
    
    # Default should be cleared
    assert_nil Askcii::Config.get('default_config_id')
  end

  def test_large_content_handling
    chat = create_test_chat
    
    # Test with very large content
    large_content = 'x' * 100_000  # 100KB of content
    message = create_test_message(chat, content: large_content)
    
    llm_message = message.to_llm
    assert_equal large_content.length, llm_message.content.length
    assert llm_message.content.valid_encoding?
  end

  def test_concurrent_chat_creation
    # Test creating chats with same context simultaneously
    context = 'concurrent_test'
    
    chat1 = Askcii::Chat.find_or_create(context: context, model_id: 'gpt-4')
    chat2 = Askcii::Chat.find_or_create(context: context, model_id: 'gpt-4')
    
    # Should return the same chat
    assert_equal chat1.id, chat2.id
  end

  def test_null_and_empty_value_handling
    chat = create_test_chat
    
    # Test with nil content
    message = chat.add_message(role: 'user', content: nil, model_id: 'gpt-4')
    llm_message = message.to_llm
    assert_equal '', llm_message.content
    
    # Test with empty string
    message2 = chat.add_message(role: 'user', content: '', model_id: 'gpt-4')
    llm_message2 = message2.to_llm
    assert_equal '', llm_message2.content
  end

  def test_environment_variable_edge_cases
    # Clear any existing configurations first
    Askcii::Config.where(Sequel.like(:key, 'config_%')).delete rescue nil
    Askcii::Config.where(key: 'default_config_id').delete rescue nil
    
    # Test with empty environment variables
    ENV['ASKCII_API_KEY'] = ''
    ENV['ASKCII_API_ENDPOINT'] = ''
    ENV['ASKCII_MODEL_ID'] = ''
    
    app = Askcii::Application.new(['test'])
    config = app.send(:determine_configuration)
    
    assert_equal '', config['api_key']
    assert_equal '', config['api_endpoint']
    assert_equal '', config['model_id']
  ensure
    ENV.delete('ASKCII_API_KEY')
    ENV.delete('ASKCII_API_ENDPOINT')
    ENV.delete('ASKCII_MODEL_ID')
  end

  def test_malformed_cli_arguments
    # Test with arguments that could cause parsing issues
    problematic_args = [
      ['--model', '-p'],  # Option as value
      ['--', '--help'],   # After separator
      ['-xyz'],           # Invalid combined options
    ]
    
    problematic_args.each do |args|
      cli = Askcii::CLI.new(args)
      
      # Should either parse successfully or raise a specific error
      begin
        cli.parse!
      rescue OptionParser::InvalidOption, OptionParser::MissingArgument
        # Expected for some cases
      end
    end
  end

  def test_chat_session_with_invalid_provider
    config = {
      'provider' => 'invalid_provider',
      'api_key' => 'test_key',
      'model_id' => 'test_model'
    }
    
    chat_session = Askcii::ChatSession.new({}, config)
    
    # Should still work but with potentially unexpected behavior
    # This tests that the code doesn't crash with unknown providers
    assert_instance_of Askcii::ChatSession, chat_session
  end

  def test_sequence_overflows
    # Test with very large ID numbers
    large_number = '999999999999999999999'
    
    # Should handle gracefully
    assert_nil Askcii::Config.get_configuration(large_number)
    refute Askcii::Config.delete_configuration(large_number)
  end

  def test_special_characters_in_configuration
    # Test configuration with special characters
    special_config = {
      'name' => 'Config with "quotes" and \'apostrophes\' & symbols',
      'api_key' => 'sk-test123!@#$%^&*()',
      'api_endpoint' => 'https://api.example.com/v1?param=value&other=test',
      'model_id' => 'model-with-dashes_and_underscores.v1',
      'provider' => 'custom-provider'
    }
    
    Askcii::Config.set('config_1', special_config.to_json)
    retrieved_config = Askcii::Config.get_configuration('1')
    
    assert_equal special_config['name'], retrieved_config['name']
    assert_equal special_config['api_key'], retrieved_config['api_key']
  end
end