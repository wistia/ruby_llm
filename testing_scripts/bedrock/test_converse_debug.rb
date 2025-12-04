#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to see raw Converse API responses
# Run with: aws-vault exec wistia-development -- env USE_AWS_BEDROCK=true bundle exec ruby test_converse_debug.rb

require 'bundler/setup'
require 'ruby_llm'
require 'json'

# Configure RubyLLM to use AWS environment variables
RubyLLM.configure do |config|
  config.bedrock_api_key = ENV['AWS_ACCESS_KEY_ID']
  config.bedrock_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.bedrock_session_token = ENV['AWS_SESSION_TOKEN']
  config.bedrock_region = ENV['AWS_REGION'] || 'us-east-2'
end

puts "Testing Bedrock Converse API response parsing..."
puts "Region: #{RubyLLM.config.bedrock_region}"
puts ""

begin
  chat = RubyLLM.chat(model: 'bedrock/global.amazon.nova-2-lite-v1:0')

  # Patch the provider to log the raw response
  provider = chat.instance_variable_get(:@provider)
  original_method = provider.method(:sync_response)

  provider.define_singleton_method(:sync_response) do |connection, payload, additional_headers = {}|
    puts "=" * 80
    puts "REQUEST PAYLOAD:"
    puts JSON.pretty_generate(payload)
    puts "=" * 80

    response = original_method.call(connection, payload, additional_headers)

    puts "=" * 80
    puts "RAW RESPONSE BODY:"
    puts JSON.pretty_generate(response.raw.body) if response.raw
    puts "=" * 80
    puts "PARSED MESSAGE:"
    puts "Content: #{response.content.inspect}"
    puts "Model ID: #{response.model_id.inspect}"
    puts "Input tokens: #{response.input_tokens.inspect}"
    puts "Output tokens: #{response.output_tokens.inspect}"
    puts "=" * 80

    response
  end

  response = chat.ask("Say 'Hello!'")
  puts "\nFinal response content: #{response.content}"

rescue StandardError => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
