# frozen_string_literal: true

require_relative 'test_helper'

class ConfigurationManagerTest < Minitest::Test
  def setup
    super
    Askcii.require_models
    Askcii.require_application
    @config_manager = Askcii::ConfigurationManager.new
  end

  def test_provider_models_constant_structure
    assert_instance_of Hash, Askcii::ConfigurationManager::PROVIDER_MODELS

    # Check that all providers have the expected structure
    Askcii::ConfigurationManager::PROVIDER_MODELS.each do |provider, config|
      assert_instance_of String, provider
      assert_instance_of Hash, config
      assert config.key?(:default), "Provider #{provider} missing :default"
      assert config.key?(:models), "Provider #{provider} missing :models"
      assert_instance_of String, config[:default]
      assert_instance_of Array, config[:models]
      assert config[:models].any?, "Provider #{provider} has no models"
      assert_includes config[:models], config[:default], "Provider #{provider} default not in models list"
    end
  end

  def test_openai_models_configuration
    openai_config = Askcii::ConfigurationManager::PROVIDER_MODELS['openai']

    assert_equal 'gpt-4o', openai_config[:default]
    assert_includes openai_config[:models], 'gpt-4o'
    assert_includes openai_config[:models], 'gpt-4o-mini'
    assert_includes openai_config[:models], 'gpt-4'
    assert_includes openai_config[:models], 'gpt-3.5-turbo'
  end

  def test_anthropic_models_configuration
    anthropic_config = Askcii::ConfigurationManager::PROVIDER_MODELS['anthropic']

    assert_equal 'claude-3-5-sonnet-20241022', anthropic_config[:default]
    assert_includes anthropic_config[:models], 'claude-3-5-sonnet-20241022'
    assert_includes anthropic_config[:models], 'claude-3-5-haiku-20241022'
    assert_includes anthropic_config[:models], 'claude-3-opus-20240229'
  end

  def test_get_model_id_with_default_selection
    # Mock stdin to return empty string (select default)
    with_stdin("\n") do
      result = @config_manager.send(:get_model_id, 'openai')
      assert_equal 'gpt-4o', result
    end
  end

  def test_get_model_id_with_numbered_selection
    # Mock stdin to return "2" (select second model)
    with_stdin("2\n") do
      result = @config_manager.send(:get_model_id, 'openai')
      assert_equal 'gpt-4o-mini', result
    end
  end

  def test_get_model_id_with_custom_model_option
    # Mock stdin to return the custom option number + custom model name
    openai_models = Askcii::ConfigurationManager::PROVIDER_MODELS['openai'][:models]
    custom_option = openai_models.length + 1

    with_stdin("#{custom_option}\ncustom-model-name\n") do
      result = @config_manager.send(:get_model_id, 'openai')
      assert_equal 'custom-model-name', result
    end
  end

  def test_get_model_id_with_invalid_selection
    # Mock stdin to return invalid number
    with_stdin("999\n") do
      result = @config_manager.send(:get_model_id, 'openai')
      assert_nil result
    end
  end

  def test_get_model_id_with_empty_custom_model
    # Mock stdin to select custom option but provide empty model name
    openai_models = Askcii::ConfigurationManager::PROVIDER_MODELS['openai'][:models]
    custom_option = openai_models.length + 1

    with_stdin("#{custom_option}\n\n") do
      result = @config_manager.send(:get_model_id, 'openai')
      assert_nil result
    end
  end

  def test_get_model_id_with_unknown_provider
    # Test fallback behavior for unknown provider
    with_stdin("test-model\n") do
      result = @config_manager.send(:get_model_id, 'unknown-provider')
      assert_equal 'test-model', result
    end
  end

  def test_get_model_id_unknown_provider_empty_input
    # Test fallback behavior with empty input
    with_stdin("\n") do
      result = @config_manager.send(:get_model_id, 'unknown-provider')
      assert_nil result
    end
  end

  def test_all_supported_providers_have_models
    supported_providers = %w[openai anthropic gemini deepseek openrouter ollama]

    supported_providers.each do |provider|
      assert Askcii::ConfigurationManager::PROVIDER_MODELS.key?(provider),
             "Provider #{provider} not found in PROVIDER_MODELS"

      config = Askcii::ConfigurationManager::PROVIDER_MODELS[provider]
      assert config[:models].length >= 1, "Provider #{provider} has no models"
      assert config[:default], "Provider #{provider} has no default model"
    end
  end

  def test_model_selection_display_includes_recommended_marker
    output = capture_stdout do
      with_stdin("\n") do
        @config_manager.send(:get_model_id, 'openai')
      end
    end

    assert_includes output, 'gpt-4o (recommended)'
    assert_includes output, 'Available models for Openai:'
    assert_includes output, 'Enter custom model ID'
  end

  def test_model_selection_shows_correct_numbering
    output = capture_stdout do
      with_stdin("\n") do
        @config_manager.send(:get_model_id, 'anthropic')
      end
    end

    # Check that models are numbered starting from 1
    assert_includes output, '  1. claude-3-5-sonnet-20241022 (recommended)'
    assert_includes output, '  2. claude-3-5-haiku-20241022'

    # Check that custom option is correctly numbered
    model_count = Askcii::ConfigurationManager::PROVIDER_MODELS['anthropic'][:models].length
    assert_includes output, "  #{model_count + 1}. Enter custom model ID"
  end

  def test_default_models_are_current_and_reasonable
    # Test that default models are reasonable choices (current flagship models)
    defaults = {
      'openai' => 'gpt-4o',
      'anthropic' => 'claude-3-5-sonnet-20241022',
      'gemini' => 'gemini-pro',
      'deepseek' => 'deepseek-chat',
      'openrouter' => 'anthropic/claude-3.5-sonnet',
      'ollama' => 'llama3.2'
    }

    defaults.each do |provider, expected_default|
      actual_default = Askcii::ConfigurationManager::PROVIDER_MODELS[provider][:default]
      assert_equal expected_default, actual_default,
                   "Default model for #{provider} should be #{expected_default}, got #{actual_default}"
    end
  end

  def test_integration_with_configuration_flow
    # Test that the enhanced model selection integrates properly
    # This is a more complex integration test

    config_manager = Askcii::ConfigurationManager.new

    # Mock the individual methods that would be called
    config_manager.stub(:get_api_key, 'test-key') do
      config_manager.stub(:get_api_endpoint, 'https://api.test.com') do
        with_stdin("\n") do # Select default model
          result = config_manager.send(:get_model_id, 'openai')
          assert_equal 'gpt-4o', result
        end
      end
    end
  end
end
