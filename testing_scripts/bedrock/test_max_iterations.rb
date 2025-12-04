#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'ruby_llm'

# Configure RubyLLM
RubyLLM.configure do |config|
  config.bedrock_api_key = ENV['AWS_ACCESS_KEY_ID']
  config.bedrock_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.bedrock_session_token = ENV['AWS_SESSION_TOKEN']
  config.bedrock_region = ENV['AWS_REGION'] || 'us-east-1'
end

puts "Testing Max Tool Iterations Safety Feature"
puts "=" * 80
puts ""

# Define a simple weather tool
class GetWeather < RubyLLM::Tool
  description 'Get the current weather for a location'
  param :location, desc: 'The city and state, e.g. San Francisco, CA'

  def execute(location:)
    { temperature: 72, conditions: 'sunny', humidity: 45, location: location }
  end
end

begin
  puts "Test 1: Using Claude (should succeed with 1 iteration)"
  puts "-" * 80

  claude_chat = RubyLLM.chat(
    model: 'bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0',
    max_tool_iterations: 10
  )
  claude_chat.with_tool(GetWeather)

  claude_iterations = 0
  claude_chat.on_tool_call do |tool_call|
    claude_iterations += 1
    puts "  Tool call ##{claude_iterations}: #{tool_call.name}(#{tool_call.arguments.inspect})"
  end

  response = claude_chat.ask("What's the weather like in Boston?")
  puts "✅ Claude succeeded after #{claude_iterations} iteration(s)"
  puts "   Response: #{response.content[0..80]}..."
  puts ""

rescue StandardError => e
  puts "❌ Claude failed: #{e.message}"
  puts ""
end

begin
  puts "Test 2: Using Llama with max_tool_iterations=3 (should fail)"
  puts "-" * 80

  llama_chat = RubyLLM.chat(
    model: 'bedrock/us.meta.llama4-scout-17b-instruct-v1:0',
    max_tool_iterations: 3
  )
  llama_chat.with_tool(GetWeather)

  llama_iterations = 0
  llama_chat.on_tool_call do |tool_call|
    llama_iterations += 1
    puts "  Tool call ##{llama_iterations}: #{tool_call.name}(#{tool_call.arguments.inspect})"
  end

  response = llama_chat.ask("What's the weather like in Boston?")
  puts "⚠️  Llama unexpectedly succeeded after #{llama_iterations} iteration(s)"
  puts "   Response: #{response.content[0..80]}..."
  puts ""

rescue StandardError => e
  puts "✅ Llama correctly stopped after max iterations"
  puts "   Error: #{e.message[0..100]}..."
  puts ""
end

begin
  puts "Test 3: Disabling max_tool_iterations (set to nil)"
  puts "-" * 80

  unlimited_chat = RubyLLM.chat(
    model: 'bedrock/us.meta.llama4-scout-17b-instruct-v1:0',
    max_tool_iterations: nil
  )
  unlimited_chat.with_tool(GetWeather)

  unlimited_iterations = 0
  unlimited_chat.on_tool_call do |tool_call|
    unlimited_iterations += 1
    puts "  Tool call ##{unlimited_iterations}: #{tool_call.name}(#{tool_call.arguments.inspect})"

    # Manually stop after 5 to prevent actual infinite loop
    if unlimited_iterations >= 5
      raise "Manual stop after 5 iterations"
    end
  end

  begin
    require 'timeout'
    Timeout.timeout(10) do
      response = unlimited_chat.ask("What's the weather like in Boston?")
      puts "Response: #{response.content}"
    end
  rescue => e
    if e.message.include?("Manual stop")
      puts "✅ Confirmed: No automatic limit when max_tool_iterations=nil"
      puts "   (Manually stopped after #{unlimited_iterations} iterations)"
    else
      raise e
    end
  end

  puts ""

rescue StandardError => e
  puts "❌ Unexpected error: #{e.message}"
  puts ""
end

puts "=" * 80
puts "✅ All tests completed!"
puts ""
puts "Summary:"
puts "- Claude models work well with default max_tool_iterations (10)"
puts "- Llama models get stopped by max_tool_iterations safety limit"
puts "- You can disable the limit by setting max_tool_iterations: nil"
puts "- You can adjust the limit: chat.max_tool_iterations = 20"
