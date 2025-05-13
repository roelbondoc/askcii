# frozen_string_literal: true

module Askcii
  class ToolCall < ActiveRecord::Base
    include RubyLLM::ActiveRecord::ActsAs

    acts_as_tool_call
  end
end
