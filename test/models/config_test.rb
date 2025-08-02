# frozen_string_literal: true

require_relative '../test_helper'

class ConfigTest < Minitest::Test
  def setup
    super
    Askcii.require_models
  end

  def test_set_and_get
    Askcii::Config.set('test_key', 'test_value')
    
    assert_equal 'test_value', Askcii::Config.get('test_key')
  end

  def test_get_nonexistent_key
    assert_nil Askcii::Config.get('nonexistent_key')
  end

  def test_legacy_api_key
    Askcii::Config.set('api_key', 'sk-test123')
    
    assert_equal 'sk-test123', Askcii::Config.api_key
  end

  def test_legacy_api_endpoint
    Askcii::Config.set('api_endpoint', 'https://api.example.com')
    
    assert_equal 'https://api.example.com', Askcii::Config.api_endpoint
  end

  def test_legacy_model_id
    Askcii::Config.set('model_id', 'gpt-4')
    
    assert_equal 'gpt-4', Askcii::Config.model_id
  end

  def test_add_configuration
    Askcii::Config.add_configuration(
      'Test Config',
      'sk-test123',
      'https://api.openai.com/v1',
      'gpt-4',
      'openai'
    )
    
    # Test by getting the configuration directly
    config = Askcii::Config.get_configuration('1')
    assert_equal 'Test Config', config['name']
    assert_equal 'sk-test123', config['api_key']
    assert_equal 'https://api.openai.com/v1', config['api_endpoint']
    assert_equal 'gpt-4', config['model_id']
    assert_equal 'openai', config['provider']
  end

  def test_configurations_with_multiple_configs
    Askcii::Config.add_configuration('Config 1', 'key1', 'endpoint1', 'model1', 'openai')
    Askcii::Config.add_configuration('Config 2', 'key2', 'endpoint2', 'model2', 'anthropic')
    
    config1 = Askcii::Config.get_configuration('1')
    config2 = Askcii::Config.get_configuration('2')
    
    assert_equal 'Config 1', config1['name']
    assert_equal 'Config 2', config2['name']
  end

  def test_get_configuration
    Askcii::Config.add_configuration('Test Config', 'key', 'endpoint', 'model', 'openai')
    
    config = Askcii::Config.get_configuration('1')
    
    refute_nil config
    assert_equal 'Test Config', config['name']
    assert_equal 'key', config['api_key']
  end

  def test_get_nonexistent_configuration
    assert_nil Askcii::Config.get_configuration('999')
  end

  def test_default_configuration_id
    # Should default to '1'
    assert_equal '1', Askcii::Config.default_configuration_id
  end

  def test_set_default_configuration
    Askcii::Config.set_default_configuration('3')
    
    assert_equal '3', Askcii::Config.default_configuration_id
  end

  def test_delete_configuration
    Askcii::Config.add_configuration('Test Config', 'key', 'endpoint', 'model', 'openai')
    
    assert Askcii::Config.delete_configuration('1')
    assert_nil Askcii::Config.get_configuration('1')
  end

  def test_delete_nonexistent_configuration
    refute Askcii::Config.delete_configuration('999')
  end

  def test_delete_default_configuration_resets_default
    Askcii::Config.add_configuration('Config 1', 'key1', 'endpoint1', 'model1', 'openai')
    Askcii::Config.add_configuration('Config 2', 'key2', 'endpoint2', 'model2', 'anthropic')
    Askcii::Config.set_default_configuration('1')
    
    # Verify config 1 exists
    assert_equal 'Config 1', Askcii::Config.get_configuration('1')['name']
    
    result = Askcii::Config.delete_configuration('1')
    assert result
    
    # Config 1 should be gone
    assert_nil Askcii::Config.get_configuration('1')
    
    # Should have a default (either '2' or '1' depending on implementation)
    refute_nil Askcii::Config.default_configuration_id
  end

  def test_delete_last_configuration_clears_default
    Askcii::Config.add_configuration('Only Config', 'key', 'endpoint', 'model', 'openai')
    Askcii::Config.set_default_configuration('1')
    
    Askcii::Config.delete_configuration('1')
    
    # Should clear the default since no configs remain
    assert_nil Askcii::Config.get('default_config_id')
  end

  def test_current_configuration_with_valid_config
    Askcii::Config.add_configuration('Current Config', 'key', 'endpoint', 'model', 'openai')
    Askcii::Config.set_default_configuration('1')
    
    config = Askcii::Config.current_configuration
    
    assert_equal 'Current Config', config['name']
    assert_equal 'openai', config['provider']
  end

  def test_current_configuration_fallback_to_legacy
    # Set some legacy config values
    Askcii::Config.set('api_key', 'legacy_key')
    Askcii::Config.set('api_endpoint', 'legacy_endpoint')
    Askcii::Config.set('model_id', 'legacy_model')
    
    config = Askcii::Config.current_configuration
    
    assert_equal 'legacy_key', config['api_key']
    assert_equal 'legacy_endpoint', config['api_endpoint']
    assert_equal 'legacy_model', config['model_id']
    assert_equal 'openai', config['provider']
  end

  def test_current_configuration_ensures_provider
    # Create config without provider
    config_data = {
      'name' => 'Test',
      'api_key' => 'key',
      'api_endpoint' => 'endpoint',
      'model_id' => 'model'
    }
    Askcii::Config.set('config_1', config_data.to_json)
    Askcii::Config.set_default_configuration('1')
    
    config = Askcii::Config.current_configuration
    
    assert_equal 'openai', config['provider']
  end

  def test_configurations_handles_invalid_json
    # Insert invalid JSON directly
    Askcii::Config.set('config_1', 'invalid json')
    
    configs = Askcii::Config.configurations
    
    assert_equal [], configs
  end

  def test_get_configuration_handles_invalid_json
    Askcii::Config.set('config_1', 'invalid json')
    
    assert_nil Askcii::Config.get_configuration('1')
  end

  def test_configuration_id_increment
    Askcii::Config.add_configuration('Config 1', 'key1', 'endpoint1', 'model1', 'openai')
    Askcii::Config.add_configuration('Config 2', 'key2', 'endpoint2', 'model2', 'anthropic')
    Askcii::Config.add_configuration('Config 3', 'key3', 'endpoint3', 'model3', 'gemini')
    
    configs = Askcii::Config.configurations
    ids = configs.map { |c| c['id'] }.sort
    
    assert_equal ['1', '2', '3'], ids
  end
end