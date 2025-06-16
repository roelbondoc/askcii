# frozen_string_literal: true

module Askcii
  class ConfigurationManager
    PROVIDER_MAP = {
      '1' => 'openai',
      '2' => 'anthropic',
      '3' => 'gemini',
      '4' => 'deepseek',
      '5' => 'openrouter',
      '6' => 'ollama'
    }.freeze

    DEFAULT_ENDPOINTS = {
      'openai' => 'https://api.openai.com/v1',
      'anthropic' => 'https://api.anthropic.com',
      'gemini' => 'https://generativelanguage.googleapis.com/v1',
      'deepseek' => 'https://api.deepseek.com/v1',
      'openrouter' => 'https://openrouter.ai/api/v1',
      'ollama' => 'http://localhost:11434/v1'
    }.freeze

    def run
      show_current_configurations
      show_menu
      handle_user_choice
    end

    private

    def show_current_configurations
      puts 'Configuration Management'
      puts '======================'

      configs = Askcii::Config.configurations
      default_id = Askcii::Config.default_configuration_id

      if configs.empty?
        puts 'No configurations found.'
      else
        puts 'Current configurations:'
        configs.each do |config|
          marker = config['id'] == default_id ? ' (default)' : ''
          provider_info = config['provider'] ? " [#{config['provider']}]" : ''
          puts "  #{config['id']}. #{config['name']}#{provider_info}#{marker}"
        end
        puts
      end
    end

    def show_menu
      puts 'Options:'
      puts '  1. Add new configuration'
      puts '  2. Set default configuration'
      puts '  3. Delete configuration'
      puts '  4. Exit'
      print 'Select option (1-4): '
    end

    def handle_user_choice
      choice = $stdin.gets.chomp

      case choice
      when '1'
        add_new_configuration
      when '2'
        set_default_configuration
      when '3'
        delete_configuration
      when '4'
        puts 'Exiting.'
      else
        puts 'Invalid option.'
      end
    end

    def add_new_configuration
      print 'Enter configuration name: '
      name = $stdin.gets.chomp

      provider = select_provider
      return unless provider

      api_key = get_api_key(provider)
      return unless api_key || provider == 'ollama'

      endpoint = get_api_endpoint(provider)
      model_id = get_model_id

      return unless model_id

      name = model_id if name.empty?
      Askcii::Config.add_configuration(name, api_key || '', endpoint, model_id, provider)
      puts 'Configuration added successfully!'
    end

    def select_provider
      puts 'Select provider:'
      puts '  1. OpenAI'
      puts '  2. Anthropic'
      puts '  3. Gemini'
      puts '  4. DeepSeek'
      puts '  5. OpenRouter'
      puts '  6. Ollama (no API key needed)'
      print 'Provider (1-6): '

      provider_choice = $stdin.gets.chomp
      provider = PROVIDER_MAP[provider_choice]

      if provider.nil?
        puts 'Invalid provider selection.'
        return nil
      end

      provider
    end

    def get_api_key(provider)
      return '' if provider == 'ollama'

      print "Enter #{provider.capitalize} API key: "
      api_key = $stdin.gets.chomp

      if api_key.empty?
        puts 'API key is required for this provider.'
        return nil
      end

      api_key
    end

    def get_api_endpoint(provider)
      default_endpoint = DEFAULT_ENDPOINTS[provider]
      print "Enter API endpoint (default: #{default_endpoint}): "
      api_endpoint = $stdin.gets.chomp
      api_endpoint.empty? ? default_endpoint : api_endpoint
    end

    def get_model_id
      print 'Enter model ID: '
      model_id = $stdin.gets.chomp

      if model_id.empty?
        puts 'Model ID is required.'
        return nil
      end

      model_id
    end

    def set_default_configuration
      configs = Askcii::Config.configurations

      if configs.empty?
        puts 'No configurations available to set as default.'
        return
      end

      print 'Enter configuration ID to set as default: '
      new_default = $stdin.gets.chomp

      if configs.any? { |c| c['id'] == new_default }
        Askcii::Config.set_default_configuration(new_default)
        puts "Configuration #{new_default} set as default."
      else
        puts 'Invalid configuration ID.'
      end
    end

    def delete_configuration
      configs = Askcii::Config.configurations

      if configs.empty?
        puts 'No configurations available to delete.'
        return
      end

      print 'Enter configuration ID to delete: '
      delete_id = $stdin.gets.chomp

      if configs.any? { |c| c['id'] == delete_id }
        if Askcii::Config.delete_configuration(delete_id)
          puts "Configuration #{delete_id} deleted successfully."
        else
          puts 'Failed to delete configuration.'
        end
      else
        puts 'Invalid configuration ID.'
      end
    end
  end
end
