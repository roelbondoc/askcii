# frozen_string_literal: true

require_relative 'test_helper'

class PipedInputTest < Minitest::Test
  def setup
    super
    Askcii.require_models
    Askcii.require_application
  end

  def test_determine_prompt_and_input_with_no_args_and_stdin
    app = Askcii::Application.new([])
    app.instance_variable_get(:@cli).parse!

    # Mock stdin with content
    app.stub(:read_stdin_input, 'What is the capital of France?') do
      prompt, input = app.send(:determine_prompt_and_input)

      assert_equal 'What is the capital of France?', prompt
      assert_nil input
    end
  end

  def test_determine_prompt_and_input_with_args_and_stdin
    app = Askcii::Application.new(%w[analyze this text])
    app.instance_variable_get(:@cli).parse!

    # Mock stdin with content
    app.stub(:read_stdin_input, 'Some context data to analyze') do
      prompt, input = app.send(:determine_prompt_and_input)

      assert_equal 'analyze this text', prompt
      assert_equal 'Some context data to analyze', input
    end
  end

  def test_determine_prompt_and_input_with_args_only
    app = Askcii::Application.new(%w[hello world])
    app.instance_variable_get(:@cli).parse!

    # Mock no stdin
    app.stub(:read_stdin_input, nil) do
      prompt, input = app.send(:determine_prompt_and_input)

      assert_equal 'hello world', prompt
      assert_nil input
    end
  end

  def test_determine_prompt_and_input_with_no_args_and_no_stdin
    app = Askcii::Application.new([])
    app.instance_variable_get(:@cli).parse!

    # Mock no stdin
    app.stub(:read_stdin_input, nil) do
      prompt, input = app.send(:determine_prompt_and_input)

      assert_equal '', prompt
      assert_nil input
    end
  end

  def test_application_shows_usage_when_no_prompt_and_no_stdin
    app = Askcii::Application.new([])

    # Mock no stdin and expect exit
    app.stub(:read_stdin_input, nil) do
      output = capture_stdout do
        assert_raises(SystemExit) { app.run }
      end

      assert_includes output, 'Usage:'
      assert_includes output, 'echo \'Your prompt here\' | askcii'
    end
  end

  def test_application_runs_with_stdin_as_prompt
    app = Askcii::Application.new([])

    # Mock configuration and stdin
    config = { 'provider' => 'openai', 'model_id' => 'gpt-4' }
    app.stub(:determine_configuration, config) do
      app.stub(:configure_llm, nil) do
        app.stub(:read_stdin_input, 'What is 2 + 2?') do
          # Mock ChatSession
          mock_session = Minitest::Mock.new
          mock_session.expect(:execute_chat, nil, ['What is 2 + 2?', nil])

          Askcii::ChatSession.stub(:new, mock_session) do
            app.run
            mock_session.verify
          end
        end
      end
    end
  end

  def test_application_runs_with_args_and_stdin_as_context
    app = Askcii::Application.new(%w[summarize this])

    # Mock configuration and stdin
    config = { 'provider' => 'openai', 'model_id' => 'gpt-4' }
    app.stub(:determine_configuration, config) do
      app.stub(:configure_llm, nil) do
        app.stub(:read_stdin_input, 'Long text to summarize...') do
          # Mock ChatSession
          mock_session = Minitest::Mock.new
          mock_session.expect(:execute_chat, nil, ['summarize this', 'Long text to summarize...'])

          Askcii::ChatSession.stub(:new, mock_session) do
            app.run
            mock_session.verify
          end
        end
      end
    end
  end

  def test_piped_input_strips_whitespace_from_prompt
    app = Askcii::Application.new([])
    app.instance_variable_get(:@cli).parse!

    # Mock stdin with content that has leading/trailing whitespace
    app.stub(:read_stdin_input, "  \n  What is Ruby?  \n  ") do
      prompt, input = app.send(:determine_prompt_and_input)

      assert_equal 'What is Ruby?', prompt
      assert_nil input
    end
  end

  def test_usage_message_includes_piped_examples
    cli = Askcii::CLI.new([])
    usage = cli.usage_message

    assert_includes usage, 'echo \'Your prompt here\' | askcii'
    assert_includes usage, '# Use piped text as prompt'
    assert_includes usage, '# Use piped text as context'
    assert_includes usage, 'cat prompt.txt | askcii'
  end

  def test_read_stdin_input_returns_nil_when_tty
    app = Askcii::Application.new([])

    # Mock tty? to return true (interactive terminal)
    $stdin.stub(:tty?, true) do
      result = app.send(:read_stdin_input)
      assert_nil result
    end
  end

  def test_read_stdin_input_returns_content_when_piped
    app = Askcii::Application.new([])

    # Mock tty? to return false (piped input) and read to return content
    $stdin.stub(:tty?, false) do
      $stdin.stub(:read, 'piped content') do
        result = app.send(:read_stdin_input)
        assert_equal 'piped content', result
      end
    end
  end
end
