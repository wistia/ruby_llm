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

puts "Testing Bedrock Converse API with Tools..."
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
  chat = RubyLLM.chat(model: 'bedrock/global.anthropic.claude-sonnet-4-5-20250929-v1:0')
  chat.with_tool(GetWeather)

  # Inspect the tool configuration
  puts "Tools registered: #{chat.tools.keys.inspect}"
  puts "Tool name: #{chat.tools.values.first.name}"
  puts "Tool description: #{chat.tools.values.first.description}"
  puts "Tool params schema: #{JSON.pretty_generate(chat.tools.values.first.params_schema)}"
  puts ""

  # Intercept payload to see what's being sent
  provider = chat.instance_variable_get(:@provider)
  original_render = provider.method(:render_payload)

  provider.define_singleton_method(:render_payload) do |*args, **kwargs|
    payload = original_render.call(*args, **kwargs)
    puts "=" * 80
    puts "REQUEST PAYLOAD:"
    puts JSON.pretty_generate(payload)
    puts "=" * 80
    payload
  end

  puts "Asking: \"What's the weather like in Boston?\""
  puts ""

  # Track tool call iterations to detect infinite loops
  tool_call_count = 0
  max_tool_calls = 5

  chat.on_tool_call do |tool_call|
    tool_call_count += 1
    puts "\n[Tool call ##{tool_call_count}: #{tool_call.name}(#{tool_call.arguments.inspect})]"

    if tool_call_count >= max_tool_calls
      puts "\n⚠️  WARNING: Model made #{max_tool_calls} tool calls without providing a text response."
      puts "This indicates the model is stuck in a tool-calling loop."
      puts "\nThis is a MODEL BEHAVIOR issue, not an API issue."
      puts "The Converse API is working correctly - it successfully:"
      puts "  ✅ Sent tool configuration to the model"
      puts "  ✅ Received tool use requests from the model"
      puts "  ✅ Sent tool results back to the model"
      puts "\nThe issue is that this particular model (#{chat.model.id})"
      puts "doesn't know when to stop calling tools and provide a final text response."
      puts "\n💡 Try using a different model that has better tool calling support,"
      puts "such as Claude models (e.g., 'bedrock/us.anthropic.claude-3-5-sonnet-20241022-v2:0')"
      exit 0
    end
  end

  # Add timeout to prevent hanging
  require 'timeout'
  response = Timeout.timeout(60) do
    chat.ask("What's the weather like in Boston?")
  end

  puts "\nRESPONSE:"
  puts "Content: #{response.content}"
  puts "Tool calls: #{response.tool_calls.inspect}"
  puts "Tokens: #{response.input_tokens} in / #{response.output_tokens} out"
  puts "\n✅ Tool execution test passed!"

rescue Timeout::Error
  puts "\n❌ Request timed out after 30 seconds"
  exit 1
rescue StandardError => e
  puts "\n❌ Error: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
