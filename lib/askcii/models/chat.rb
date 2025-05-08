module Askcii
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
end