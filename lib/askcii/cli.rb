# frozen_string_literal: true

require 'optparse'

module Askcii
  class CLI
    attr_reader :options, :prompt

    def initialize(args = ARGV.dup)
      @args = args
      @options = {}
      @prompt = nil
    end

    def parse!
      option_parser.parse!(@args)
      @prompt = @args.join(' ')
      self
    end

    def show_help?
      @options[:help]
    end

    def show_usage?
      false  # Usage logic is now handled in Application class
    end

    def configure?
      @options[:configure]
    end

    def last_response?
      @options[:last_response]
    end

    def private?
      @options[:private]
    end

    def model_config_id
      @options[:model_config_id]
    end

    def help_message
      option_parser.to_s
    end

    def usage_message
      <<~USAGE
        Usage:
          askcii [options] 'Your prompt here'
          echo 'Your prompt here' | askcii                    # Use piped text as prompt
          echo 'Context text' | askcii 'Your prompt here'     # Use piped text as context
          askcii 'Your prompt here' < prompt.txt              # Use file content as context
          cat prompt.txt | askcii                             # Use file content as prompt
          askcii -p (start a private session)
          askcii -r (to get the last response)
          askcii -c (manage configurations)
          askcii -m 2 (use configuration ID 2)

        Options:
          -p, --private         Start a private session and do not record
          -r, --last-response   Output the last response
          -c, --configure       Manage configurations
          -m, --model ID        Use specific configuration ID
          -h, --help            Show help
      USAGE
    end

    private

    def option_parser
      @option_parser ||= OptionParser.new do |opts|
        opts.banner = "Usage: askcii [options] 'Your prompt here'"

        opts.on('-p', '--private', 'Start a private session and do not record') do
          @options[:private] = true
        end

        opts.on('-r', '--last-response', 'Output the last response') do
          @options[:last_response] = true
        end

        opts.on('-c', '--configure', 'Manage configurations') do
          @options[:configure] = true
        end

        opts.on('-m', '--model ID', 'Use specific configuration ID') do |model_id|
          @options[:model_config_id] = model_id
        end

        opts.on('-h', '--help', 'Show this help message') do
          @options[:help] = true
        end
      end
    end
  end
end
