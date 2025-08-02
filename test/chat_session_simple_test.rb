# frozen_string_literal: true

require_relative 'test_helper'

class ChatSessionSimpleTest < Minitest::Test
  def setup
    super
    Askcii.require_models
    Askcii.require_application

    @options = { private: false, last_response: false }
    @config = {
      'provider' => 'openai',
      'api_key' => 'test_key',
      'api_endpoint' => 'https://api.openai.com/v1',
      'model_id' => 'gpt-4'
    }
    @chat_session = Askcii::ChatSession.new(@options, @config)
  end

  def test_initialization
    assert_instance_of Askcii::ChatSession, @chat_session
    assert_equal @options, @chat_session.instance_variable_get(:@options)
    assert_equal @config, @chat_session.instance_variable_get(:@selected_config)
  end

  def test_handle_last_response_without_option
    @options[:last_response] = false
    chat_session = Askcii::ChatSession.new(@options, @config)

    # Should return early and not do anything
    assert_nil chat_session.handle_last_response
  end

  def test_handle_last_response_with_existing_message
    @options[:last_response] = true
    chat_session = Askcii::ChatSession.new(@options, @config)

    # Create a chat with an assistant message
    chat = create_test_chat(context: 'test_context', model_id: 'gpt-4')
    create_test_message(chat, role: 'assistant', content: 'Previous response')

    ENV['ASKCII_SESSION'] = 'test_context'

    output = capture_stdout do
      assert_raises(SystemExit) { chat_session.handle_last_response }
    end

    assert_includes output, 'Previous response'
  ensure
    ENV.delete('ASKCII_SESSION')
  end

  def test_handle_last_response_without_existing_message
    @options[:last_response] = true
    chat_session = Askcii::ChatSession.new(@options, @config)

    ENV['ASKCII_SESSION'] = 'test_context'

    output = capture_stdout do
      assert_raises(SystemExit) { chat_session.handle_last_response }
    end

    assert_includes output, 'No previous response found.'
  ensure
    ENV.delete('ASKCII_SESSION')
  end

  def test_create_persistent_chat_basic
    chat_session = Askcii::ChatSession.new(@options, @config)

    # This will create a new chat
    result = chat_session.send(:create_persistent_chat)

    # Should return some kind of chat object
    refute_nil result
  end

  def test_create_persistent_chat_with_session_env
    ENV['ASKCII_SESSION'] = 'custom_session'

    chat_session = Askcii::ChatSession.new(@options, @config)

    # Should use the custom session
    result = chat_session.send(:create_persistent_chat)
    refute_nil result
  ensure
    ENV.delete('ASKCII_SESSION')
  end
end
