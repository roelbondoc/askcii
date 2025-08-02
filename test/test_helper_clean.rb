# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'minitest/pride'
require 'tempfile'
require 'fileutils'
require 'csv'
require 'ostruct'

# Set up test environment before loading askcii
ENV['ASKCII_LOG_LEVEL'] = 'ERROR'

# Temporarily store original method if it exists

module Minitest
  class Test
    @@test_db_counter = 0

    def setup
      super
      @@test_db_counter += 1
      @original_env = ENV.to_h
      @temp_db_dir = Dir.mktmpdir("askcii_test_#{@@test_db_counter}")
      @temp_db_path = File.join(@temp_db_dir, 'test_askcii.db')

      # Create a unique module for this test's database path
      test_module = Module.new do
        define_singleton_method(:db_path) { @temp_db_path }
      end

      # Load askcii if not already loaded
      require 'askcii' unless defined?(Askcii)

      # Extend Askcii with our test module for this test
      Askcii.extend(test_module)

      # Reset the database connection
      Askcii.remove_class_variable(:@@database) if Askcii.class_variable_defined?(:@@database)

      # Setup test database
      Askcii.setup_database
    end

    def teardown
      super
      # Restore original environment
      ENV.clear
      ENV.update(@original_env)

      # Clean up temp database
      FileUtils.rm_rf(@temp_db_dir) if @temp_db_dir && File.exist?(@temp_db_dir)

      # Reset database connection
      Askcii.remove_class_variable(:@@database) if Askcii.class_variable_defined?(:@@database)
    end

    # Helper method to capture stdout
    def capture_stdout
      old_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end

    # Helper method to capture stderr
    def capture_stderr
      old_stderr = $stderr
      $stderr = StringIO.new
      yield
      $stderr.string
    ensure
      $stderr = old_stderr
    end

    # Helper method to mock stdin
    def with_stdin(input)
      old_stdin = $stdin
      $stdin = StringIO.new(input)
      yield
    ensure
      $stdin = old_stdin
    end

    # Helper method to create a test chat
    def create_test_chat(context: 'test_context', model_id: 'test_model')
      Askcii::Chat.create(context: context, model_id: model_id)
    end

    # Helper method to create a test message
    def create_test_message(chat, role: 'user', content: 'test content')
      chat.add_message(
        role: role,
        content: content,
        model_id: chat.model_id
      )
    end
  end
end
