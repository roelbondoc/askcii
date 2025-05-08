#!/usr/bin/env ruby

require 'tempfile'
require 'sqlite3'
require 'active_record'
require 'active_support'
require_relative './ruby_llm/lib/ruby_llm'
require_relative './ruby_llm/lib/ruby_llm/active_record/acts_as'

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: "askcii.db"
)

# only create if table is defined
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
    t.text :arguments, default: "{}"
    t.timestamps
  end
  ActiveRecord::Migration.add_index :tool_calls, :tool_call_id
end

class Chat < ActiveRecord::Base
  include RubyLLM::ActiveRecord::ActsAs

  acts_as_chat

  def to_llm
    @chat ||= RubyLLM.chat(
      model: model_id,
      provider: :openai,
      assume_model_exists: true
    )
    super
  end
end

class Message < ActiveRecord::Base
  include RubyLLM::ActiveRecord::ActsAs

  acts_as_message
end

class ToolCall < ActiveRecord::Base
  include RubyLLM::ActiveRecord::ActsAs

  acts_as_tool_call
end

RubyLLM.configure do |config|
  config.log_file = "/dev/null"
  config.openai_api_key = "blank"
  config.openai_api_base = "http://localhost:11434/v1"
end

input = nil

if !STDIN.tty?
  input = STDIN.read
end

prompt = ARGV.join(" ")

if prompt.empty?
  puts "Usage:"
  puts "  askcii 'Your prompt here'"
  puts "  echo 'Your prompt here' | askcii 'Your prompt here'"
  puts "  askcii `Your prompt here` < prompt.txt"
  exit 1
end

context = ENV['ASKCII_SESSION_ID'] || Dir.pwd
chat = Chat.find_or_create_by(context: context, model_id: 'gemma3:12b')

chat.with_instructions "You are a helpful command line application. Your responses should be suitable to be read in a terminal.", replace: true
prompt = "With the following text:\n\n#{input}\n\n#{prompt}" if input

chat.ask(prompt) do |chunk|
  print chunk.content
end
puts ""
