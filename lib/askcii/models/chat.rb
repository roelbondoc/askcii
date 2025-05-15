# frozen_string_literal: true

module Askcii
  class Chat < Sequel::Model(Askcii.database[:chats])
    one_to_many :messages, class: 'Askcii::Message', key: :chat_id

    def to_llm
      @chat = RubyLLM.chat(
        model: model_id,
        provider: :openai,
        assume_model_exists: true
      )
      messages.each do |msg|
        @chat.add_message(msg.to_llm)
      end
      @chat.on_new_message { persist_new_message }
      @chat.on_end_message { |msg| persist_message_completion(msg) }
      @chat
    end

    def persist_new_message
      @message = add_message(
        role: :assistant,
        content: String.new
      )
    end

    def persist_message_completion(message)
      return unless message

      @message.update(
        role: message.role,
        content: message.content,
        model_id: message.model_id,
        input_tokens: message.input_tokens,
        output_tokens: message.output_tokens
      )
    end
  end
end
