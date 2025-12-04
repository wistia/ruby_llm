#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'ruby_llm'
require 'json'

# Configure RubyLLM
RubyLLM.configure do |config|
  config.bedrock_api_key = ENV['AWS_ACCESS_KEY_ID']
  config.bedrock_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.bedrock_session_token = ENV['AWS_SESSION_TOKEN']
  config.bedrock_region = ENV['AWS_REGION'] || 'us-east-1'
end

puts "Making a simple Bedrock Converse API call..."
puts ""

begin
  # Create a connection directly
  provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)
  provider.instance_variable_set(:@model_id, 'global.amazon.nova-2-lite-v1:0')

  # Build a simple payload
  payload = {
    messages: [
      {
        role: 'user',
        content: [{ text: 'Say hello!' }]
      }
    ],
    inferenceConfig: {
      maxTokens: 100
    }
  }

  puts "Request URL: #{provider.api_base}/model/global.amazon.nova-2-lite-v1:0/converse"
  puts ""
  puts "Request Payload:"
  puts JSON.pretty_generate(payload)
  puts ""
  puts "=" * 80

  # Make the request
  signature = provider.send(:sign_request, "#{provider.api_base}/model/global.amazon.nova-2-lite-v1:0/converse", payload: payload)

  response = provider.connection.post "model/global.amazon.nova-2-lite-v1:0/converse", payload do |req|
    req.headers.merge! provider.send(:build_headers, signature.headers, streaming: false)
  end

  puts "Response Status: #{response.status}"
  puts ""
  puts "Response Body:"
  puts JSON.pretty_generate(response.body)
  puts "=" * 80

rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
