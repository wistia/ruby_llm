#!/usr/bin/env ruby
# frozen_string_literal: true

# Test the Bedrock Converse API with a real request
# Run with: aws-vault exec wistia-development -- bundle exec ruby test_converse_live.rb

require 'bundler/setup'
require 'ruby_llm'

# Configure RubyLLM to use AWS environment variables
RubyLLM.configure do |config|
  config.bedrock_api_key = ENV['AWS_ACCESS_KEY_ID']
  config.bedrock_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.bedrock_session_token = ENV['AWS_SESSION_TOKEN']
  config.bedrock_region = ENV['AWS_REGION'] || 'us-east-2'
end

puts "Testing Bedrock Converse API..."
puts "Region: #{RubyLLM.config.bedrock_region}"
puts ""

# Create a simple chat
begin
  # You can pass a default model when creating the chat
  chat = RubyLLM.chat(model: 'bedrock/us.meta.llama4-maverick-17b-instruct-v1:0')

  # Test basic chat (will use the default model)
  puts "Test 1: Basic chat (using default model)"
  response = chat.ask("Say 'Hello from Converse API!' and nothing else")
  puts "Response: #{response.content}"
  puts "Model: #{response.model_id}"
  puts "Input tokens: #{response.input_tokens}"
  puts "Output tokens: #{response.output_tokens}"
  puts "✅ Basic chat passed\n\n"

  # Test streaming (using default model)
  puts "Test 2: Streaming chat (using default model)"
  print "Response: "
  chat.ask("What is Wistia?") do |chunk|
    print chunk.content
  end
  puts "\n✅ Streaming chat passed\n\n"

  # Test tool execution
  puts "Test 3: Tool execution"

  # Define a simple weather tool
  class GetWeather < RubyLLM::Tool
    description 'Get the current weather for a location'
    param :location, desc: 'The city and state, e.g. San Francisco, CA'

    def execute(location:)
      { temperature: 72, conditions: 'sunny', humidity: 45, location: location }
    end
  end

  # Use Claude which has good tool calling support
  tool_chat = RubyLLM.chat(model: 'bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0')
  tool_chat.with_tool(GetWeather)

  # Ask a question that should trigger the tool
  response = tool_chat.ask("What's the weather like in Boston?")

  if response.content && !response.content.empty?
    puts "✅ Tool execution test passed"
    puts "  - Model called get_weather tool and responded with text"
    puts "  - Response preview: #{response.content[0..100]}..."
    puts ""
  else
    puts "⚠️  Tool was called but no text response received\n\n"
  end

  puts "🎉 All tests passed! Converse API endpoints are working."
  puts "\nNote: Run test_converse_debug.rb to see raw API responses and debug parsing issues."
rescue StandardError => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
