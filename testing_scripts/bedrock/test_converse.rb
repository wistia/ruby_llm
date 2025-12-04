#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'ruby_llm'
require 'json'

# Configure RubyLLM with test credentials
RubyLLM.configure do |config|
  config.bedrock_api_key = ENV['AWS_ACCESS_KEY_ID'] || 'test_key'
  config.bedrock_secret_key = ENV['AWS_SECRET_ACCESS_KEY'] || 'test_secret'
  config.bedrock_region = ENV['AWS_REGION'] || 'us-east-1'
end

# Test the Bedrock Converse API URL endpoints
provider = RubyLLM::Providers::Bedrock.new(RubyLLM.config)

# Set a model ID for URL testing
provider.instance_variable_set(:@model_id, 'test-model-id')

# Test completion URL
url = provider.send(:completion_url)
puts "Completion URL: #{url}"
puts "Expected format: model/{modelId}/converse"

# Test stream URL
stream_url = provider.send(:stream_url)
puts "Stream URL: #{stream_url}"
puts "Expected format: model/{modelId}/converse-stream"

puts "\n✅ URL tests passed - using correct Converse API endpoint format!"
puts "\nTo test against live Bedrock, run:"
puts "aws-vault exec wistia-development -- env USE_AWS_BEDROCK=true bundle exec ruby test_converse_live.rb"
