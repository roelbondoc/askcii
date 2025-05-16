# frozen_string_literal: true

module Askcii
  class Message < Sequel::Model(Askcii.database[:messages])
    many_to_one :chat, class: 'Askcii::Chat', key: :chat_id

    def to_llm
      RubyLLM::Message.new(
        role: role.to_sym,
        content: content.to_s.encode("UTF-8", undef: :replace),
        tool_calls: {},
        tool_call_id: nil,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        model_id: model_id
      )
    end
  end
end
