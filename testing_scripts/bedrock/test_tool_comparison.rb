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

puts "Comparing Tool Calling Behavior: Claude vs Llama"
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

def test_model(model_name, max_iterations: 3)
  puts "\n" + "=" * 80
  puts "Testing: #{model_name}"
  puts "=" * 80

  chat = RubyLLM.chat(model: "bedrock/#{model_name}")
  chat.with_tool(GetWeather)

  # Capture all responses
  responses = []
  iteration = 0

  # Intercept connection to capture raw responses
  connection = chat.instance_variable_get(:@connection)
  original_post = connection.method(:post)

  connection.define_singleton_method(:post) do |url, payload = nil, &block|
    result = original_post.call(url, payload, &block)

    # Store the raw response body
    if result.respond_to?(:body)
      responses << {
        iteration: iteration,
        request_url: url,
        request_payload: payload,
        response_body: result.body
      }
    end

    result
  end

  # Track tool calls
  tool_calls = []
  chat.on_tool_call do |tool_call|
    iteration += 1
    tool_calls << {
      iteration: iteration,
      name: tool_call.name,
      arguments: tool_call.arguments
    }

    puts "\n[Iteration #{iteration}] Tool call: #{tool_call.name}(#{tool_call.arguments.inspect})"

    if iteration >= max_iterations
      puts "\n⚠️  Stopping after #{max_iterations} iterations to prevent infinite loop"
      raise "MaxIterationsReached"
    end
  end

  begin
    response = chat.ask("What's the weather like in Boston?")

    puts "\n✅ Final response received!"
    puts "Content: #{response.content[0..200]}..."
    puts ""

    {
      model: model_name,
      success: true,
      final_response: response.content,
      tool_calls: tool_calls,
      responses: responses
    }
  rescue => e
    if e.message == "MaxIterationsReached"
      puts "\n❌ Model got stuck in tool-calling loop"
      puts ""

      {
        model: model_name,
        success: false,
        error: "Tool calling loop detected",
        tool_calls: tool_calls,
        responses: responses
      }
    else
      raise e
    end
  end
end

begin
  # Test both models
  claude_result = test_model('global.anthropic.claude-sonnet-4-5-20250929-v1:0', max_iterations: 3)
  llama_result = test_model('us.meta.llama4-maverick-17b-instruct-v1:0', max_iterations: 3)

  # Save detailed comparison
  puts "\n" + "=" * 80
  puts "DETAILED RESPONSE COMPARISON"
  puts "=" * 80

  File.open('tool_comparison_output.json', 'w') do |f|
    f.puts JSON.pretty_generate({
      claude: claude_result,
      llama: llama_result,
      analysis: {
        claude_iterations: claude_result[:tool_calls].length,
        llama_iterations: llama_result[:tool_calls].length,
        claude_success: claude_result[:success],
        llama_success: llama_result[:success]
      }
    })
  end

  puts "\n✅ Detailed comparison saved to: tool_comparison_output.json"
  puts "\nKey differences:"
  puts "- Claude: #{claude_result[:tool_calls].length} tool call(s), #{claude_result[:success] ? 'SUCCESS' : 'FAILED'}"
  puts "- Llama: #{llama_result[:tool_calls].length} tool call(s), #{llama_result[:success] ? 'SUCCESS' : 'FAILED'}"

  # Show first response from each
  puts "\n" + "=" * 80
  puts "CLAUDE - First API Response:"
  puts "=" * 80
  if claude_result[:responses].any?
    puts JSON.pretty_generate(claude_result[:responses].first[:response_body])
  else
    puts "(No responses captured)"
  end

  puts "\n" + "=" * 80
  puts "LLAMA - First API Response:"
  puts "=" * 80
  if llama_result[:responses].any?
    puts JSON.pretty_generate(llama_result[:responses].first[:response_body])
  else
    puts "(No responses captured)"
  end

  puts "\n" + "=" * 80
  puts "CLAUDE - Second API Response (after tool execution):"
  puts "=" * 80
  if claude_result[:responses].length > 1
    puts JSON.pretty_generate(claude_result[:responses][1][:response_body])
  else
    puts "(Only one response)"
  end

  puts "\n" + "=" * 80
  puts "LLAMA - Second API Response (after tool execution):"
  puts "=" * 80
  if llama_result[:responses].length > 1
    puts JSON.pretty_generate(llama_result[:responses][1][:response_body])
  else
    puts "(Only one response)"
  end

  # Show third response for Llama
  if llama_result[:responses].length > 2
    puts "\n" + "=" * 80
    puts "LLAMA - Third API Response (still calling tools):"
    puts "=" * 80
    puts JSON.pretty_generate(llama_result[:responses][2][:response_body])
  end

rescue StandardError => e
  puts "\n❌ Error: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
