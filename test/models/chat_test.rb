# frozen_string_literal: true

require_relative '../test_helper'

class ChatTest < Minitest::Test
  def setup
    super
    Askcii.require_models
  end

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

  def test_chat_has_messages_association
    chat = create_test_chat

    assert_respond_to chat, :messages
    assert_instance_of Array, chat.messages
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
  end

  def test_to_llm_creates_ruby_llm_chat
    chat = create_test_chat(model_id: 'gpt-4')

    # Mock the configuration
    mock_config = { 'provider' => 'openai' }
    Askcii::Config.stub(:current_configuration, mock_config) do
      mock_ruby_llm_chat do |mock_chat|
        result = chat.to_llm
        assert_equal mock_chat, result
      end
    end
  end

  def test_to_llm_adds_existing_messages
    chat = create_test_chat(model_id: 'gpt-4')
    create_test_message(chat, role: 'user', content: 'Test message')

    mock_config = { 'provider' => 'openai' }
    Askcii::Config.stub(:current_configuration, mock_config) do
      mock_ruby_llm_chat do |mock_chat|
        mock_chat.expect(:add_message, nil, [Object])
        mock_chat.expect(:on_new_message, nil) { |&block| block }
        mock_chat.expect(:on_end_message, nil) { |&block| block }

        chat.to_llm
        mock_chat.verify
      end
    end
  end

  def test_persist_new_message
    chat = create_test_chat

    new_message = chat.persist_new_message

    assert_instance_of Askcii::Message, new_message
    assert_equal 'assistant', new_message.role
    assert_equal '', new_message.content
    assert_equal chat.id, new_message.chat_id
  end

  def test_persist_message_completion
    chat = create_test_chat
    message = chat.add_message(role: 'assistant', content: '')

    # Set the instance variable that would be set by persist_new_message
    chat.instance_variable_set(:@message, message)

    mock_llm_message = OpenStruct.new(
      role: 'assistant',
      content: 'Completed response',
      model_id: 'gpt-4',
      input_tokens: 10,
      output_tokens: 20
    )

    chat.persist_message_completion(mock_llm_message)

    message.reload
    assert_equal 'assistant', message.role
    assert_equal 'Completed response', message.content
    assert_equal 'gpt-4', message.model_id
    assert_equal 10, message.input_tokens
    assert_equal 20, message.output_tokens
  end

  def test_persist_message_completion_with_nil_message
    chat = create_test_chat

    # Should not raise an error when message is nil
    assert_nil chat.persist_message_completion(nil)
  end
end
