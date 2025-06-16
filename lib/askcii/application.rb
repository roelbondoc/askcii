# frozen_string_literal: true

require_relative 'cli'
require_relative 'configuration_manager'
require_relative 'chat_session'

module Askcii
  class Application
    def initialize(args = ARGV.dup)
      @cli = CLI.new(args)
    end

    def run
      @cli.parse!

      if @cli.show_help?
        puts @cli.help_message
        exit 0
      end

      if @cli.configure?
        ConfigurationManager.new.run
        exit 0
      end

      if @cli.show_usage?
        puts @cli.usage_message
        exit 1
      end

      selected_config = determine_configuration
      configure_llm(selected_config)

      chat_session = ChatSession.new(@cli.options, selected_config)
      chat_session.handle_last_response if @cli.last_response?

      input = read_stdin_input
      chat_session.execute_chat(@cli.prompt, input)
    end

    private

    def determine_configuration
      if @cli.model_config_id
        config = Askcii::Config.get_configuration(@cli.model_config_id)
        return config if config
      end

      config = Askcii::Config.current_configuration
      return config if config

      # Fallback to environment variables
      {
        'api_key' => ENV['ASKCII_API_KEY'],
        'api_endpoint' => ENV['ASKCII_API_ENDPOINT'],
        'model_id' => ENV['ASKCII_MODEL_ID']
      }
    end

    def configure_llm(selected_config)
      Askcii.configure_llm(selected_config)
    end

    def read_stdin_input
      return nil if $stdin.tty?

      $stdin.read
    end
  end
end
