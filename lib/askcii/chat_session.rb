# frozen_string_literal: true

require 'securerandom'

module Askcii
  class ChatSession
    def initialize(options, selected_config)
      @options = options
      @selected_config = selected_config
    end

    def handle_last_response
      return unless @options[:last_response]

      context = ENV['ASKCII_SESSION'] || SecureRandom.hex(8)
      model_id = @selected_config['model_id']
      chat_record = Askcii::Chat.find_or_create(context: context, model_id: model_id)

      last_message = chat_record.messages.where(role: 'assistant').last
      if last_message
        puts last_message.content
        exit 0
      else
        puts 'No previous response found.'
        exit 1
      end
    end

    def create_chat
      if @options[:private]
        create_private_chat
      else
        create_persistent_chat
      end
    end

    def execute_chat(prompt, input = nil)
      chat = create_chat

      chat.with_instructions 'You are a command line application. Your responses should be suitable to be read in a terminal. Your responses should only include the necessary text. Do not include any explanations unless prompted for it.'

      full_prompt = input ? "With the following text:\n\n#{input}\n\n#{prompt}" : prompt

      chat.ask(full_prompt) do |chunk|
        print chunk.content
      end
      puts ''
    end

    private

    def create_private_chat
      provider_symbol = @selected_config['provider'] ? @selected_config['provider'].to_sym : :openai
      model_id = @selected_config['model_id']

      RubyLLM.chat(
        model: model_id,
        provider: provider_symbol,
        assume_model_exists: true
      )
    end

    def create_persistent_chat
      context = ENV['ASKCII_SESSION'] || SecureRandom.hex(8)
      model_id = @selected_config['model_id']
      chat_record = Askcii::Chat.find_or_create(context: context, model_id: model_id)
      chat_record.to_llm
    end
  end
end
