# frozen_string_literal: true

require 'tempfile'
require 'sqlite3'
require 'active_record'
require 'active_support'
require 'fileutils'
require 'ruby_llm'
require 'ruby_llm/model_info'
require 'ruby_llm/active_record/acts_as'
require_relative './askcii/version'

module Askcii
  class Error < StandardError; end

  # Get the path to the database file
  def self.db_path
    db_dir = File.join(ENV['HOME'], '.local', 'share', 'askcii')
    FileUtils.mkdir_p(db_dir) unless Dir.exist?(db_dir)
    File.join(db_dir, 'chats.db')
  end

  # Initialize the database
  def self.setup_database
    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3',
      database: db_path
    )

    ActiveRecord::Migration.verbose = false

    unless ActiveRecord::Base.connection.table_exists?(:chats)
      ActiveRecord::Migration.create_table :chats do |t|
        t.string :model_id
        t.string :context
        t.timestamps
      end
    end

    unless ActiveRecord::Base.connection.table_exists?(:messages)
      ActiveRecord::Migration.create_table :messages do |t|
        t.references :chat, null: false, foreign_key: true
        t.string :role
        t.text :content
        t.string :model_id
        t.integer :input_tokens
        t.integer :output_tokens
        t.references :tool_call
        t.timestamps
      end
    end

    unless ActiveRecord::Base.connection.table_exists?(:tool_calls)
      ActiveRecord::Migration.create_table :tool_calls do |t|
        t.references :message, null: false, foreign_key: true
        t.string :tool_call_id, null: false
        t.string :name, null: false
        t.text :arguments, default: '{}'
        t.timestamps
      end
      ActiveRecord::Migration.add_index :tool_calls, :tool_call_id
    end

    # Create configurations table if it doesn't exist
    return if ActiveRecord::Base.connection.table_exists?(:configs)

    ActiveRecord::Migration.create_table :configs do |t|
      t.string :key, null: false, index: { unique: true }
      t.text :value, null: false
      t.timestamps
    end
  end

  def self.configure_llm
    RubyLLM.configure do |config|
      config.log_file = '/dev/null'

      # Try to get configuration from the database first, then fallback to ENV variables
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

# Define model classes
require_relative './askcii/models/chat'
require_relative './askcii/models/message'
require_relative './askcii/models/tool_call'
require_relative './askcii/models/config'
