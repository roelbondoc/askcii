# frozen_string_literal: true

require_relative '../test_helper'

class MessageTest < Minitest::Test
  def setup
    super
    Askcii.require_models
    @chat = create_test_chat
  end

  def test_message_creation
    message = Askcii::Message.create(
      chat_id: @chat.id,
      role: 'user',
      content: 'Hello, world!',
      model_id: 'gpt-4'
    )
    
    assert_instance_of Askcii::Message, message
    assert_equal @chat.id, message.chat_id
    assert_equal 'user', message.role
    assert_equal 'Hello, world!', message.content
    assert_equal 'gpt-4', message.model_id
    refute_nil message.created_at
  end

  def test_message_belongs_to_chat
    message = create_test_message(@chat)
    
    assert_respond_to message, :chat
    assert_equal @chat.id, message.chat.id
  end

  def test_to_llm_conversion
    message = create_test_message(
      @chat,
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
    assert_equal({}, llm_message.tool_calls)
    assert_nil llm_message.tool_call_id
  end

  def test_to_llm_handles_unicode_content
    message = create_test_message(
      @chat,
      content: "Hello 👋 with émojis and spëcial chars"
    )
    
    llm_message = message.to_llm
    
    assert_equal "Hello 👋 with émojis and spëcial chars", llm_message.content
    assert llm_message.content.valid_encoding?
  end

  def test_to_llm_handles_invalid_encoding
    message = create_test_message(@chat)
    # Create string with invalid encoding
    invalid_content = "Hello\xFF\xFEWorld".dup.force_encoding('UTF-8')
    message.update(content: invalid_content)
    
    llm_message = message.to_llm
    
    assert llm_message.content.valid_encoding?
    assert_includes llm_message.content, 'Hello'
    assert_includes llm_message.content, 'World'
  end

  def test_to_llm_converts_role_to_symbol
    message = create_test_message(@chat, role: 'user')
    
    llm_message = message.to_llm
    
    assert_equal :user, llm_message.role
    assert_instance_of Symbol, llm_message.role
  end

  def test_to_llm_handles_nil_values
    message = create_test_message(@chat)
    message.update(
      input_tokens: nil,
      output_tokens: nil,
      model_id: nil
    )
    
    llm_message = message.to_llm
    
    assert_nil llm_message.input_tokens
    assert_nil llm_message.output_tokens
    assert_nil llm_message.model_id
  end

  def test_content_to_string_conversion
    message = create_test_message(@chat, content: nil)
    
    llm_message = message.to_llm
    
    assert_equal '', llm_message.content
  end

  def test_message_token_tracking
    message = create_test_message(@chat)
    message.update(
      input_tokens: 100,
      output_tokens: 50
    )
    
    assert_equal 100, message.input_tokens
    assert_equal 50, message.output_tokens
  end
end