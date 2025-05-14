# frozen_string_literal: true

module Askcii
  class Config < ActiveRecord::Base
    validates :key, presence: true, uniqueness: true
    validates :value, presence: true

    # Helper methods for common configuration values
    class << self
      def api_key
        find_by(key: 'api_key')&.value
      end

      def api_endpoint
        find_by(key: 'api_endpoint')&.value
      end

      def model_id
        find_by(key: 'model_id')&.value
      end

      def set(key, value)
        config = find_or_initialize_by(key: key)
        config.value = value
        config.save
      end
    end
  end
end
