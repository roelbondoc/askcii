#!/usr/bin/env ruby

require_relative './ruby_llm/lib/ruby_llm'
require 'tempfile'

RubyLLM.configure do |config|
  config.log_file = "/dev/null"
  config.openai_api_key = "blank"
  config.openai_api_base = "http://localhost:11434/v1"
end

input = nil

if !STDIN.tty?
  input = STDIN.read
end

instruction = ARGV.join(" ")

if instruction.empty?
  puts "Usage:"
  puts "  askcii 'Your prompt here'"
  puts "  echo 'Your prompt here' | askcii 'Your prompt here'"
  puts "  askcii `Your prompt here` < prompt.txt"
  exit 1
end

prompt = ""
prompt = "With the following text:\n\n#{input}\n\n" if input
prompt += instruction

chat = RubyLLM::Chat.new(model: 'gemma3:1b', provider: :openai, assume_model_exists: true)

chat.ask(prompt) do |chunk|
  print chunk.content
end
puts ""
