# frozen_string_literal: true

require 'sequel'
require 'fileutils'
require 'ruby_llm'
require_relative './askcii/version'

module Askcii
  class Error < StandardError; end

  def self.database
    @@database ||= Sequel.amalgalite(db_path)
  end

  # Get the path to the database file
  def self.db_path
    db_dir = File.join(ENV['HOME'], '.local', 'share', 'askcii')
    FileUtils.mkdir_p(db_dir) unless Dir.exist?(db_dir)
    File.join(db_dir, 'askcii.db')
  end

  # Initialize the database
  def self.setup_database
    unless database.table_exists?(:chats)
      database.create_table :chats do
        primary_key :id
        String :model_id, null: true
        String :context, null: true
        Datetime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      end
    end

    unless database.table_exists?(:messages)
      database.create_table :messages do
        primary_key :id
        foreign_key :chat_id, :chats, null: false
        String :role, null: true
        Text :content, null: true
        String :model_id, null: true
        Integer :input_tokens, null: true
        Integer :output_tokens, null: true
        Datetime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      end
    end

    return if database.table_exists?(:configs)

    database.create_table :configs do
      primary_key :id
      String :key, null: false, unique: true
      Text :value, null: true
    end
  end

  def self.configure_llm(selected_config = nil)
    RubyLLM.configure do |config|
      config.log_file = '/dev/null'

      if selected_config
        provider = selected_config['provider'] || 'openai'
        api_key = selected_config['api_key']

        # Set the appropriate API key based on provider
        case provider.downcase
        when 'openai'
          config.openai_api_key = api_key || 'blank'
          config.openai_api_base = selected_config['api_endpoint'] || 'https://api.openai.com/v1'
        when 'anthropic'
          config.anthropic_api_key = api_key || 'blank'
        when 'gemini'
          config.gemini_api_key = api_key || 'blank'
        when 'deepseek'
          config.deepseek_api_key = api_key || 'blank'
        when 'openrouter'
          config.openrouter_api_key = api_key || 'blank'
        when 'ollama'
          # Ollama doesn't need an API key
          config.openai_api_base = selected_config['api_endpoint'] || 'http://localhost:11434/v1'
        end
      else
        # Legacy configuration fallback
        config.openai_api_key = begin
          Askcii::Config.api_key || ENV['ASKCII_API_KEY'] || 'blank'
        rescue StandardError
          ENV['ASKCII_API_KEY'] || 'blank'
        end

        config.openai_api_base = begin
          Askcii::Config.api_endpoint || ENV['ASKCII_API_ENDPOINT'] || 'http://localhost:11434/v1'
        rescue StandardError
          ENV['ASKCII_API_ENDPOINT'] || 'http://localhost:11434/v1'
        end
      end
    end
  end

  def self.require_models
    require_relative './askcii/models/chat'
    require_relative './askcii/models/message'
    require_relative './askcii/models/config'
  end

  def self.require_application
    require_relative './askcii/application'
  end
end
