# frozen_string_literal: true

require 'json'

module Askcii
  class Config < Sequel::Model(Askcii.database[:configs])
    def self.set(key, value)
      config = find_or_create(key: key)
      config.update(value: value)
    end

    def self.get(key)
      config = find(key: key)
      config&.value
    end

    # Legacy methods for backward compatibility
    def self.api_key
      get('api_key')
    end

    def self.api_endpoint
      get('api_endpoint')
    end

    def self.model_id
      get('model_id')
    end

    # New multi-configuration methods
    def self.configurations
      where(Sequel.like(:key, 'config_%')).map do |config|
        config_data = JSON.parse(config.value)
        config_data.merge('id' => config.key.split('_', 2)[1])
      end
    rescue JSON::ParserError
      []
    end

    def self.add_configuration(name, api_key, api_endpoint, model_id, provider)
      config_data = {
        'name' => name,
        'api_key' => api_key,
        'api_endpoint' => api_endpoint,
        'model_id' => model_id,
        'provider' => provider
      }

      # Find the next available ID
      existing_ids = configurations.map { |c| c['id'].to_i }.sort
      next_id = existing_ids.empty? ? 1 : existing_ids.last + 1

      set("config_#{next_id}", config_data.to_json)
    end

    def self.get_configuration(id)
      config = get("config_#{id}")
      return nil unless config

      JSON.parse(config)
    rescue JSON::ParserError
      nil
    end

    def self.default_configuration_id
      get('default_config_id') || '1'
    end

    def self.set_default_configuration(id)
      set('default_config_id', id.to_s)
    end

    def self.delete_configuration(id)
      config = find(key: "config_#{id}")
      return false unless config

      # Check if this is the default configuration
      if default_configuration_id == id.to_s
        # Reset default to the first remaining configuration
        remaining_configs = configurations.reject { |c| c['id'] == id.to_s }
        if remaining_configs.any?
          set_default_configuration(remaining_configs.first['id'])
        else
          # If no configurations remain, clear the default
          config_record = find(key: 'default_config_id')
          config_record&.delete
        end
      end

      config.delete
      true
    end

    def self.current_configuration
      default_id = default_configuration_id
      config = get_configuration(default_id)

      # Fallback to legacy configuration if no multi-configs exist
      if config.nil? && configurations.empty?
        {
          'api_key' => api_key,
          'api_endpoint' => api_endpoint,
          'model_id' => model_id,
          'provider' => 'openai'
        }
      else
        # Ensure provider is set for backward compatibility
        config ||= {}
        config['provider'] ||= 'openai'
        config
      end
    end
  end
end
