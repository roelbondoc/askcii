# frozen_string_literal: true

require_relative 'test_helper'

class ChatSessionTest < Minitest::Test
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
    
    # Create a chat without assistant messages
    create_test_chat(context: 'test_context', model_id: 'gpt-4')
    
    ENV['ASKCII_SESSION'] = 'test_context'
    
    output = capture_stdout do
      assert_raises(SystemExit) { chat_session.handle_last_response }
    end
    
    assert_includes output, 'No previous response found.'
  ensure
    ENV.delete('ASKCII_SESSION')
  end

  def test_handle_last_response_generates_session_context
    @options[:last_response] = true
    chat_session = Askcii::ChatSession.new(@options, @config)
    
    # Don't set ASKCII_SESSION, should generate one
    output = capture_stdout do
      assert_raises(SystemExit) { chat_session.handle_last_response }
    end
    
    assert_includes output, 'No previous response found.'
  end

  def test_create_chat_private
    @options[:private] = true
    chat_session = Askcii::ChatSession.new(@options, @config)
    
    mock_ruby_llm_chat do |mock_chat|
      result = chat_session.send(:create_chat)
      assert_equal mock_chat, result
    end
  end

  def test_create_chat_persistent
    @options[:private] = false
    chat_session = Askcii::ChatSession.new(@options, @config)
    
    # Mock the to_llm method on the chat
    mock_chat = Minitest::Mock.new
    
    Askcii::Chat.stub(:find_or_create, mock_chat) do
      mock_chat.expect(:to_llm, mock_chat)
      result = chat_session.send(:create_chat)
      assert_equal mock_chat, result
      mock_chat.verify
    end
  end

  def test_execute_chat_with_prompt_only
    prompt = 'Test prompt'
    
    mock_chat = Minitest::Mock.new
    mock_chat.expect(:with_instructions, nil, [String])
    mock_chat.expect(:ask, nil, [prompt])
    
    @chat_session.stub(:create_chat, mock_chat) do
      output = capture_stdout do
        @chat_session.execute_chat(prompt) do |chunk|
          print 'Test response'
        end
      end
      
      assert_includes output, 'Test response'
      mock_chat.verify
    end
  end

  def test_execute_chat_with_prompt_and_input
    prompt = 'Analyze this'
    input = 'Input text'
    expected_full_prompt = "With the following text:\n\n#{input}\n\n#{prompt}"
    
    mock_chat = Minitest::Mock.new
    mock_chat.expect(:with_instructions, nil, [String])
    mock_chat.expect(:ask, nil, [expected_full_prompt]) do |&block|
      yield(OpenStruct.new(content: 'Analysis result'))
    end
    
    @chat_session.stub(:create_chat, mock_chat) do
      output = capture_stdout do
        @chat_session.execute_chat(prompt, input)
      end
      
      assert_includes output, 'Analysis result'
      mock_chat.verify
    end
  end

  def test_create_private_chat
    @config['provider'] = 'anthropic'
    @config['model_id'] = 'claude-3'
    
    chat_session = Askcii::ChatSession.new(@options, @config)
    
    mock_ruby_llm_chat do |mock_chat|
      result = chat_session.send(:create_private_chat)
      assert_equal mock_chat, result
    end
  end

  def test_create_private_chat_with_default_provider
    @config.delete('provider')
    
    chat_session = Askcii::ChatSession.new(@options, @config)
    
    mock_ruby_llm_chat do |mock_chat|
      result = chat_session.send(:create_private_chat)
      assert_equal mock_chat, result
    end
  end

  def test_create_persistent_chat
    chat_session = Askcii::ChatSession.new(@options, @config)
    
    mock_chat = Minitest::Mock.new
    mock_chat.expect(:to_llm, mock_chat)
    
    Askcii::Chat.stub(:find_or_create, mock_chat) do
      result = chat_session.send(:create_persistent_chat)
      assert_equal mock_chat, result
      mock_chat.verify
    end
  end

  def test_create_persistent_chat_with_session_env
    ENV['ASKCII_SESSION'] = 'custom_session'
    
    chat_session = Askcii::ChatSession.new(@options, @config)
    
    Askcii::Chat.stub(:find_or_create, proc { |args|
      assert_equal 'custom_session', args[:context]
      assert_equal 'gpt-4', args[:model_id]
      mock_chat = Minitest::Mock.new
      mock_chat.expect(:to_llm, mock_chat)
      mock_chat
    }) do
      chat_session.send(:create_persistent_chat)
    end
  ensure
    ENV.delete('ASKCII_SESSION')
  end

  def test_chat_instructions_are_set
    prompt = 'Test prompt'
    expected_instructions = 'You are a command line application. Your responses should be suitable to be read in a terminal. Your responses should only include the necessary text. Do not include any explanations unless prompted for it.'
    
    mock_chat = Minitest::Mock.new
    mock_chat.expect(:with_instructions, nil, [expected_instructions])
    mock_chat.expect(:ask, nil, [prompt]) do |&block|
      yield(OpenStruct.new(content: 'Response'))
    end
    
    @chat_session.stub(:create_chat, mock_chat) do
      capture_stdout do
        @chat_session.execute_chat(prompt)
      end
      mock_chat.verify
    end
  end
end