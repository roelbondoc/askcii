# frozen_string_literal: true

module Askcii
  class Config < Sequel::Model(Askcii.database[:configs])
    def self.set(key, value)
      config = find_or_create(key: key)
      config.update(value: value)
    end

    def self.get(key)
      config = find(key: key)
      config ? config.value : nil
    end

    def self.api_key
      get('api_key')
    end

    def self.api_endpoint
      get('api_endpoint')
    end

    def self.model_id
      get('model_id')
    end
  end
end
