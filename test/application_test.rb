# frozen_string_literal: true

require_relative 'test_helper'

class ApplicationTest < Minitest::Test
  def setup
    super
    Askcii.require_models
    Askcii.require_application
  end

  def test_initialization_with_default_args
    app = Askcii::Application.new

    assert_instance_of Askcii::Application, app
    cli = app.instance_variable_get(:@cli)
    assert_instance_of Askcii::CLI, cli
  end

  def test_initialization_with_custom_args
    args = ['--help']
    app = Askcii::Application.new(args)

    cli = app.instance_variable_get(:@cli)
    # The args should be passed to CLI
    assert_instance_of Askcii::CLI, cli
  end

  def test_run_with_help_option
    app = Askcii::Application.new(['--help'])

    output = capture_stdout do
      assert_raises(SystemExit) { app.run }
    end

    assert_includes output, 'Usage:'
  end

  def test_run_with_configure_option
    app = Askcii::Application.new(['--configure'])

    # Mock ConfigurationManager
    mock_config_manager = Minitest::Mock.new
    mock_config_manager.expect(:run, nil)

    Askcii::ConfigurationManager.stub(:new, mock_config_manager) do
      assert_raises(SystemExit) { app.run }
      mock_config_manager.verify
    end
  end

  def test_run_with_empty_prompt_shows_usage
    app = Askcii::Application.new([])

    output = capture_stdout do
      assert_raises(SystemExit) { app.run }
    end

    assert_includes output, 'Usage:'
  end

  def test_run_with_last_response_option
    app = Askcii::Application.new(['--last-response'])

    # Mock ChatSession
    mock_chat_session = Minitest::Mock.new
    mock_chat_session.expect(:handle_last_response, nil)

    Askcii::ChatSession.stub(:new, mock_chat_session) do
      # Mock determine_configuration and configure_llm
      app.stub(:determine_configuration, {}) do
        app.stub(:configure_llm, nil) do
          app.stub(:read_stdin_input, nil) do
            mock_chat_session.expect(:execute_chat, nil, [String, nil])
            app.run
            mock_chat_session.verify
          end
        end
      end
    end
  end

  def test_run_with_prompt_executes_chat
    app = Askcii::Application.new(%w[test prompt])

    mock_chat_session = Minitest::Mock.new
    mock_chat_session.expect(:execute_chat, nil, ['test prompt', nil])

    Askcii::ChatSession.stub(:new, mock_chat_session) do
      app.stub(:determine_configuration, {}) do
        app.stub(:configure_llm, nil) do
          app.stub(:read_stdin_input, nil) do
            app.run
            mock_chat_session.verify
          end
        end
      end
    end
  end

  def test_run_with_stdin_input
    app = Askcii::Application.new(%w[analyze this])
    stdin_input = 'input from stdin'

    mock_chat_session = Minitest::Mock.new
    mock_chat_session.expect(:execute_chat, nil, ['analyze this', stdin_input])

    Askcii::ChatSession.stub(:new, mock_chat_session) do
      app.stub(:determine_configuration, {}) do
        app.stub(:configure_llm, nil) do
          app.stub(:read_stdin_input, stdin_input) do
            app.run
            mock_chat_session.verify
          end
        end
      end
    end
  end

  def test_determine_configuration_with_model_config_id
    # Add a test configuration
    Askcii::Config.add_configuration('Test Config', 'key', 'endpoint', 'model', 'openai')

    app = Askcii::Application.new(['--model', '1', 'test'])

    config = app.send(:determine_configuration)

    assert_equal 'Test Config', config['name']
    assert_equal 'key', config['api_key']
  end

  def test_determine_configuration_with_current_config
    # Add and set a default configuration
    Askcii::Config.add_configuration('Default Config', 'default_key', 'default_endpoint', 'default_model', 'openai')
    Askcii::Config.set_default_configuration('1')

    app = Askcii::Application.new(['test'])

    config = app.send(:determine_configuration)

    assert_equal 'Default Config', config['name']
  end

  def test_determine_configuration_fallback_to_env
    # Clear any existing configurations first
    begin
      Askcii::Config.where(Sequel.like(:key, 'config_%')).delete
    rescue StandardError
      nil
    end
    begin
      Askcii::Config.where(key: 'default_config_id').delete
    rescue StandardError
      nil
    end

    app = Askcii::Application.new(['test'])

    ENV['ASKCII_API_KEY'] = 'env_key'
    ENV['ASKCII_API_ENDPOINT'] = 'env_endpoint'
    ENV['ASKCII_MODEL_ID'] = 'env_model'

    config = app.send(:determine_configuration)

    assert_equal 'env_key', config['api_key']
    assert_equal 'env_endpoint', config['api_endpoint']
    assert_equal 'env_model', config['model_id']
  ensure
    ENV.delete('ASKCII_API_KEY')
    ENV.delete('ASKCII_API_ENDPOINT')
    ENV.delete('ASKCII_MODEL_ID')
  end

  def test_configure_llm_calls_askcii_configure
    app = Askcii::Application.new(['test'])
    config = { 'provider' => 'openai' }

    configure_called = false
    Askcii.stub(:configure_llm, proc { |c|
      configure_called = true
      assert_equal config, c
    }) do
      app.send(:configure_llm, config)
    end

    assert configure_called
  end

  def test_read_stdin_input_with_tty
    app = Askcii::Application.new(['test'])

    $stdin.stub(:tty?, true) do
      result = app.send(:read_stdin_input)
      assert_nil result
    end
  end

  def test_read_stdin_input_with_pipe
    app = Askcii::Application.new(['test'])
    input_data = 'piped input data'

    $stdin.stub(:tty?, false) do
      $stdin.stub(:read, input_data) do
        result = app.send(:read_stdin_input)
        assert_equal input_data, result
      end
    end
  end

  def test_full_workflow_with_private_option
    app = Askcii::Application.new(['--private', 'test', 'prompt'])

    mock_chat_session = Minitest::Mock.new
    mock_chat_session.expect(:execute_chat, nil, ['test prompt', nil])

    Askcii::ChatSession.stub(:new, proc { |options, _config|
      assert_equal true, options[:private]
      mock_chat_session
    }) do
      app.stub(:determine_configuration, {}) do
        app.stub(:configure_llm, nil) do
          app.stub(:read_stdin_input, nil) do
            app.run
            mock_chat_session.verify
          end
        end
      end
    end
  end

  def test_integration_with_real_cli_parsing
    app = Askcii::Application.new(['--private', '--model', '1', 'hello', 'world'])

    # Parse the CLI to verify it works end-to-end
    cli = app.instance_variable_get(:@cli)
    cli.parse!

    assert cli.private?
    assert_equal '1', cli.model_config_id
    assert_equal 'hello world', cli.prompt
  end
end
