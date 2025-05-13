# frozen_string_literal: true

module Askcii
  class Message < ActiveRecord::Base
    include RubyLLM::ActiveRecord::ActsAs

    acts_as_message
  end
end
