# frozen_string_literal: true

require_relative 'test_helper'

class CLITest < Minitest::Test
  def setup
    super
    Askcii.require_application
  end

  def test_initialization
    cli = Askcii::CLI.new(%w[test prompt])

    assert_instance_of Askcii::CLI, cli
    assert_equal({}, cli.options)
    assert_nil cli.prompt
  end

  def test_parse_basic_prompt
    cli = Askcii::CLI.new(%w[hello world])
    cli.parse!

    assert_equal 'hello world', cli.prompt
    assert_equal({}, cli.options)
  end

  def test_parse_help_option
    cli = Askcii::CLI.new(['--help'])
    cli.parse!

    assert cli.show_help?
    assert_equal true, cli.options[:help]
  end

  def test_parse_help_short_option
    cli = Askcii::CLI.new(['-h'])
    cli.parse!

    assert cli.show_help?
    assert_equal true, cli.options[:help]
  end

  def test_parse_private_option
    cli = Askcii::CLI.new(['--private', 'test'])
    cli.parse!

    assert cli.private?
    assert_equal true, cli.options[:private]
    assert_equal 'test', cli.prompt
  end

  def test_parse_private_short_option
    cli = Askcii::CLI.new(['-p', 'test'])
    cli.parse!

    assert cli.private?
    assert_equal true, cli.options[:private]
  end

  def test_parse_last_response_option
    cli = Askcii::CLI.new(['--last-response'])
    cli.parse!

    assert cli.last_response?
    assert_equal true, cli.options[:last_response]
  end

  def test_parse_last_response_short_option
    cli = Askcii::CLI.new(['-r'])
    cli.parse!

    assert cli.last_response?
    assert_equal true, cli.options[:last_response]
  end

  def test_parse_configure_option
    cli = Askcii::CLI.new(['--configure'])
    cli.parse!

    assert cli.configure?
    assert_equal true, cli.options[:configure]
  end

  def test_parse_configure_short_option
    cli = Askcii::CLI.new(['-c'])
    cli.parse!

    assert cli.configure?
    assert_equal true, cli.options[:configure]
  end

  def test_parse_model_option
    cli = Askcii::CLI.new(['--model', '2', 'test'])
    cli.parse!

    assert_equal '2', cli.model_config_id
    assert_equal '2', cli.options[:model_config_id]
    assert_equal 'test', cli.prompt
  end

  def test_parse_model_short_option
    cli = Askcii::CLI.new(['-m', '3', 'test'])
    cli.parse!

    assert_equal '3', cli.model_config_id
    assert_equal '3', cli.options[:model_config_id]
  end

  def test_parse_multiple_options
    cli = Askcii::CLI.new(['--private', '--model', '1', 'hello', 'world'])
    cli.parse!

    assert cli.private?
    assert_equal '1', cli.model_config_id
    assert_equal 'hello world', cli.prompt
  end

  def test_show_usage_with_empty_prompt
    cli = Askcii::CLI.new([])
    cli.parse!

    assert cli.show_usage?
  end

  def test_show_usage_with_configure_option
    cli = Askcii::CLI.new(['--configure'])
    cli.parse!

    refute cli.show_usage?
  end

  def test_show_usage_with_last_response_option
    cli = Askcii::CLI.new(['--last-response'])
    cli.parse!

    refute cli.show_usage?
  end

  def test_show_usage_with_prompt
    cli = Askcii::CLI.new(%w[test prompt])
    cli.parse!

    refute cli.show_usage?
  end

  def test_help_message
    cli = Askcii::CLI.new([])
    message = cli.help_message

    assert_includes message, 'Usage:'
    assert_includes message, '--private'
    assert_includes message, '--last-response'
    assert_includes message, '--configure'
    assert_includes message, '--model'
    assert_includes message, '--help'
  end

  def test_usage_message
    cli = Askcii::CLI.new([])
    message = cli.usage_message

    assert_includes message, 'Usage:'
    assert_includes message, 'askcii [options]'
    assert_includes message, 'echo'
    assert_includes message, '-p'
    assert_includes message, '-r'
    assert_includes message, '-c'
    assert_includes message, '-m'
    assert_includes message, '-h'
  end

  def test_parse_preserves_quoted_arguments
    cli = Askcii::CLI.new(%w[explain this code please])
    cli.parse!

    assert_equal 'explain this code please', cli.prompt
  end

  def test_parse_with_no_arguments
    cli = Askcii::CLI.new([])
    cli.parse!

    assert_equal '', cli.prompt
    assert cli.show_usage?
  end

  def test_option_parsing_with_unknown_options
    # This should raise an error for unknown options
    cli = Askcii::CLI.new(['--unknown-option', 'prompt'])

    assert_raises(OptionParser::InvalidOption) do
      cli.parse!
    end
  end

  def test_option_methods_return_false_by_default
    cli = Askcii::CLI.new(['test'])
    cli.parse!

    refute cli.show_help?
    refute cli.configure?
    refute cli.last_response?
    refute cli.private?
    assert_nil cli.model_config_id
  end

  def test_option_parser_returns_self
    cli = Askcii::CLI.new(['test'])
    result = cli.parse!

    assert_same cli, result
  end

  def test_complex_prompt_parsing
    cli = Askcii::CLI.new(['--private', 'analyze', 'this', 'complex', 'prompt', 'with', 'many', 'words'])
    cli.parse!

    assert cli.private?
    assert_equal 'analyze this complex prompt with many words', cli.prompt
  end

  def test_model_option_without_value
    cli = Askcii::CLI.new(['--model'])

    assert_raises(OptionParser::MissingArgument) do
      cli.parse!
    end
  end

  def test_banner_in_help_message
    cli = Askcii::CLI.new([])
    help_message = cli.help_message

    assert_includes help_message, "Usage: askcii [options] 'Your prompt here'"
  end
end
