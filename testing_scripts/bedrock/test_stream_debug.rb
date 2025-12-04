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

puts "Testing Bedrock Converse Stream API..."
puts ""

begin
  chat = RubyLLM.chat(model: 'bedrock/global.amazon.nova-2-lite-v1:0')

  # Intercept the streaming to see raw chunks
  provider = chat.instance_variable_get(:@provider)

  # Store original method
  original_process_payload = provider.method(:process_payload)

  # Override to log
  chunk_count = 0
  provider.define_singleton_method(:process_payload) do |payload, &block|
    json_payload = payload[(payload.index('{'))...(payload.rindex('}') + 1)]
    data = JSON.parse(json_payload)

    chunk_count += 1
    puts "\n" + "=" * 80
    puts "CHUNK ##{chunk_count}:"
    puts JSON.pretty_generate(data)
    puts "=" * 80

    original_process_payload.call(payload, &block)
  rescue JSON::ParserError => e
    puts "Failed to parse: #{e.message}"
  end

  puts "Asking: 'Count from 1 to 3'"
  puts "\nStream output: "

  response = chat.ask("Count from 1 to 3") do |chunk|
    print "[#{chunk.content}]"
  end

  puts "\n\nFinal response:"
  puts "Content: #{response.content}"
  puts "Tokens: #{response.input_tokens} in / #{response.output_tokens} out"

rescue StandardError => e
  puts "\n❌ Error: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
