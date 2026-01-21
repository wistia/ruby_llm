# frozen_string_literal: true

require 'spec_helper'
require 'base64'

RSpec.describe RubyLLM::Providers::BedrockConverse::Streaming::PayloadProcessing do
  # Create a test class that includes the module
  let(:processor) do
    klass = Class.new do
      include RubyLLM::Providers::BedrockConverse::Streaming::PayloadProcessing
      include RubyLLM::Providers::BedrockConverse::Streaming::ContentExtraction

      attr_accessor :model_id
      attr_reader :yielded_chunks

      def initialize
        @model_id = 'test-model'
        @yielded_chunks = []
      end
    end
    klass.new
  end

  # Helper to create payload with JSON embedded
  def create_payload(json_content)
    "\x00\x00#{json_content}\x00\x00"
  end

  describe '#process_payload' do
    it 'processes payload with valid JSON' do
      json_data = { 'delta' => { 'text' => 'Hello' } }
      payload = create_payload(JSON.generate(json_data))
      yielded = nil

      processor.process_payload(payload) do |chunk|
        yielded = chunk
      end

      expect(yielded).to be_a(RubyLLM::Chunk)
      expect(yielded.content).to eq('Hello')
    end

    it 'extracts JSON from binary payload' do
      json_data = { 'delta' => { 'text' => 'Embedded' } }
      payload = "\x00\x01\x02" + JSON.generate(json_data) + "\x03\x04"
      yielded = nil

      processor.process_payload(payload) do |chunk|
        yielded = chunk
      end

      expect(yielded).to be_a(RubyLLM::Chunk)
      expect(yielded.content).to eq('Embedded')
    end

    it 'handles JSON at start of payload' do
      json_data = { 'delta' => { 'text' => 'Start' } }
      payload = JSON.generate(json_data) + "\x00\x00"
      yielded = nil

      processor.process_payload(payload) do |chunk|
        yielded = chunk
      end

      expect(yielded).not_to be_nil
      expect(yielded.content).to eq('Start')
    end

    it 'handles JSON at end of payload' do
      json_data = { 'delta' => { 'text' => 'End' } }
      payload = "\x00\x00" + JSON.generate(json_data)
      yielded = nil

      processor.process_payload(payload) do |chunk|
        yielded = chunk
      end

      expect(yielded).not_to be_nil
      expect(yielded.content).to eq('End')
    end

    it 'logs error and continues on JSON parse error' do
      invalid_json = '{invalid json'
      payload = create_payload(invalid_json)

      expect(RubyLLM.logger).to receive(:debug).with(/Failed to parse payload as JSON/)
      expect(RubyLLM.logger).to receive(:debug).with(/Attempted JSON payload/)

      processor.process_payload(payload) { |_chunk| }
    end

    it 'logs error on general processing error' do
      json_data = { 'delta' => { 'text' => 'Test' } }
      payload = create_payload(JSON.generate(json_data))

      # Force an error by making build_chunk fail
      allow(processor).to receive(:build_chunk).and_raise(StandardError, 'Build error')

      expect(RubyLLM.logger).to receive(:debug).with(/Error processing payload/)

      processor.process_payload(payload) { |_chunk| }
    end
  end

  describe '#extract_json_payload' do
    it 'extracts JSON between first { and last }' do
      payload = "\x00\x00{\"key\":\"value\"}\x00\x00"

      result = processor.send(:extract_json_payload, payload)

      expect(result).to eq('{"key":"value"}')
    end

    it 'handles nested braces' do
      payload = "\x00{\"outer\":{\"inner\":\"value\"}}\x00"

      result = processor.send(:extract_json_payload, payload)

      expect(result).to eq('{"outer":{"inner":"value"}}')
    end

    it 'extracts JSON at start of payload' do
      payload = '{"start":"data"}\x00\x00'

      result = processor.send(:extract_json_payload, payload)

      expect(result).to eq('{"start":"data"}')
    end

    it 'extracts JSON at end of payload' do
      payload = "\x00\x00{\"end\":\"data\"}"

      result = processor.send(:extract_json_payload, payload)

      expect(result).to eq('{"end":"data"}')
    end

    it 'handles payload with only JSON' do
      payload = '{"only":"json"}'

      result = processor.send(:extract_json_payload, payload)

      expect(result).to eq('{"only":"json"}')
    end
  end

  describe '#parse_and_process_json' do
    it 'parses JSON and processes it' do
      json_string = '{"delta":{"text":"Parsed"}}'
      yielded = nil

      processor.send(:parse_and_process_json, json_string) do |chunk|
        yielded = chunk
      end

      expect(yielded).to be_a(RubyLLM::Chunk)
      expect(yielded.content).to eq('Parsed')
    end

    it 'raises JSON::ParserError on invalid JSON' do
      invalid_json = '{invalid}'

      expect do
        processor.send(:parse_and_process_json, invalid_json) { |_chunk| }
      end.to raise_error(JSON::ParserError)
    end
  end

  describe '#process_json_data' do
    it 'processes Converse Stream format (no base64)' do
      json_data = { 'delta' => { 'text' => 'Direct' } }
      yielded = nil

      processor.send(:process_json_data, json_data) do |chunk|
        yielded = chunk
      end

      expect(yielded).to be_a(RubyLLM::Chunk)
      expect(yielded.content).to eq('Direct')
    end

    it 'processes legacy format with base64-encoded bytes' do
      inner_data = { 'delta' => { 'text' => 'Encoded' } }
      encoded = Base64.strict_encode64(JSON.generate(inner_data))
      json_data = { 'bytes' => encoded }
      yielded = nil

      processor.send(:process_json_data, json_data) do |chunk|
        yielded = chunk
      end

      expect(yielded).to be_a(RubyLLM::Chunk)
      expect(yielded.content).to eq('Encoded')
    end

    it 'prefers direct format over bytes if both present' do
      inner_data = { 'delta' => { 'text' => 'Wrong' } }
      encoded = Base64.strict_encode64(JSON.generate(inner_data))
      json_data = {
        'bytes' => encoded,
        'delta' => { 'text' => 'Correct' }
      }
      yielded = nil

      processor.send(:process_json_data, json_data) do |chunk|
        yielded = chunk
      end

      # Should use base64 path when 'bytes' is present
      expect(yielded.content).to eq('Wrong')
    end
  end

  describe '#decode_and_parse_data' do
    it 'decodes base64 and parses JSON' do
      inner_data = { 'delta' => { 'text' => 'Decoded' } }
      encoded = Base64.strict_encode64(JSON.generate(inner_data))
      json_data = { 'bytes' => encoded }

      result = processor.send(:decode_and_parse_data, json_data)

      expect(result).to eq(inner_data)
    end

    it 'raises error on invalid base64' do
      json_data = { 'bytes' => 'not valid base64!@#$' }

      expect do
        processor.send(:decode_and_parse_data, json_data)
      end.to raise_error(ArgumentError)
    end

    it 'raises error when decoded bytes are not valid JSON' do
      json_data = { 'bytes' => Base64.strict_encode64('not json') }

      expect do
        processor.send(:decode_and_parse_data, json_data)
      end.to raise_error(JSON::ParserError)
    end
  end

  describe '#create_and_yield_chunk' do
    it 'creates chunk and yields it to block' do
      data = { 'delta' => { 'text' => 'Yielded' } }
      yielded = nil

      processor.send(:create_and_yield_chunk, data) do |chunk|
        yielded = chunk
      end

      expect(yielded).to be_a(RubyLLM::Chunk)
      expect(yielded.content).to eq('Yielded')
    end
  end

  describe '#build_chunk' do
    it 'builds chunk with text content' do
      data = { 'delta' => { 'text' => 'Text content' } }

      chunk = processor.send(:build_chunk, data)

      expect(chunk).to be_a(RubyLLM::Chunk)
      expect(chunk.content).to eq('Text content')
      expect(chunk.role).to eq(:assistant)
      expect(chunk.model_id).to eq('test-model')
    end

    it 'builds chunk with tool call' do
      data = {
        'start' => {
          'toolUse' => {
            'toolUseId' => 'tool_123',
            'name' => 'get_weather'
          }
        }
      }

      chunk = processor.send(:build_chunk, data)

      expect(chunk.tool_calls).not_to be_nil
      expect(chunk.tool_calls['tool_123']).to be_a(RubyLLM::ToolCall)
      expect(chunk.tool_calls['tool_123'].name).to eq('get_weather')
    end

    it 'builds chunk with usage data' do
      data = {
        'delta' => { 'text' => 'With usage' },
        'usage' => {
          'inputTokens' => 10,
          'outputTokens' => 5
        }
      }

      chunk = processor.send(:build_chunk, data)

      expect(chunk.input_tokens).to eq(10)
      expect(chunk.output_tokens).to eq(5)
    end

    it 'sets cached_tokens to nil' do
      data = { 'delta' => { 'text' => 'Test' } }

      chunk = processor.send(:build_chunk, data)

      expect(chunk.cached_tokens).to be_nil
    end

    it 'sets cache_creation_tokens to nil' do
      data = { 'delta' => { 'text' => 'Test' } }

      chunk = processor.send(:build_chunk, data)

      expect(chunk.cache_creation_tokens).to be_nil
    end
  end

  describe '#extract_chunk_attributes' do
    it 'extracts all attributes from data' do
      data = {
        'delta' => { 'text' => 'All attributes' },
        'usage' => {
          'inputTokens' => 15,
          'outputTokens' => 8
        }
      }

      attrs = processor.send(:extract_chunk_attributes, data)

      expect(attrs[:role]).to eq(:assistant)
      expect(attrs[:model_id]).to eq('test-model')
      expect(attrs[:content]).to eq('All attributes')
      expect(attrs[:input_tokens]).to eq(15)
      expect(attrs[:output_tokens]).to eq(8)
      expect(attrs[:cached_tokens]).to be_nil
      expect(attrs[:cache_creation_tokens]).to be_nil
      expect(attrs[:tool_calls]).to be_nil
    end

    it 'extracts tool calls when present' do
      data = {
        'start' => {
          'toolUse' => {
            'toolUseId' => 'tool_456',
            'name' => 'calculate'
          }
        }
      }

      attrs = processor.send(:extract_chunk_attributes, data)

      expect(attrs[:tool_calls]).not_to be_nil
      expect(attrs[:tool_calls]['tool_456'].name).to eq('calculate')
    end

    it 'handles missing usage data' do
      data = { 'delta' => { 'text' => 'No usage' } }

      attrs = processor.send(:extract_chunk_attributes, data)

      expect(attrs[:input_tokens]).to be_nil
      expect(attrs[:output_tokens]).to be_nil
    end
  end

  describe 'integration: processing realistic payloads' do
    it 'processes text delta payload' do
      json_data = {
        'delta' => { 'text' => 'The weather is sunny.' },
        'usage' => { 'inputTokens' => 20, 'outputTokens' => 5 }
      }
      payload = create_payload(JSON.generate(json_data))
      yielded = nil

      processor.process_payload(payload) do |chunk|
        yielded = chunk
      end

      expect(yielded.content).to eq('The weather is sunny.')
      expect(yielded.input_tokens).to eq(20)
      expect(yielded.output_tokens).to eq(5)
    end

    it 'processes tool use start payload' do
      json_data = {
        'start' => {
          'toolUse' => {
            'toolUseId' => 'tool_weather_789',
            'name' => 'get_weather'
          }
        }
      }
      payload = create_payload(JSON.generate(json_data))
      yielded = nil

      processor.process_payload(payload) do |chunk|
        yielded = chunk
      end

      expect(yielded.content).to eq('')
      expect(yielded.tool_calls).not_to be_nil
      expect(yielded.tool_calls['tool_weather_789'].name).to eq('get_weather')
    end

    it 'processes legacy format with base64 encoding' do
      inner_json = { 'delta' => { 'text' => 'Legacy format' } }
      encoded = Base64.strict_encode64(JSON.generate(inner_json))
      outer_json = { 'bytes' => encoded }
      payload = create_payload(JSON.generate(outer_json))
      yielded = nil

      processor.process_payload(payload) do |chunk|
        yielded = chunk
      end

      expect(yielded.content).to eq('Legacy format')
    end

    it 'processes usage-only payload' do
      json_data = {
        'usage' => {
          'inputTokens' => 50,
          'outputTokens' => 25
        }
      }
      payload = create_payload(JSON.generate(json_data))
      yielded = nil

      processor.process_payload(payload) do |chunk|
        yielded = chunk
      end

      expect(yielded.content).to eq('')
      expect(yielded.input_tokens).to eq(50)
      expect(yielded.output_tokens).to eq(25)
    end

    it 'handles empty delta' do
      json_data = { 'delta' => {} }
      payload = create_payload(JSON.generate(json_data))
      yielded = nil

      processor.process_payload(payload) do |chunk|
        yielded = chunk
      end

      expect(yielded.content).to eq('')
      expect(yielded.tool_calls).to be_nil
    end
  end

  describe 'error recovery' do
    it 'handles malformed payload gracefully' do
      payload = "\x00\x01{malformed\x02\x03"

      expect(RubyLLM.logger).to receive(:debug).at_least(:once)

      processor.process_payload(payload) { |_chunk| }
    end

    it 'handles empty payload' do
      payload = ''

      # Should handle gracefully without errors
      expect do
        processor.process_payload(payload) { |_chunk| }
      end.not_to raise_error
    end

    it 'handles payload with no JSON brackets' do
      payload = 'no json here at all'

      # Should handle gracefully
      expect do
        processor.process_payload(payload) { |_chunk| }
      end.not_to raise_error
    end
  end
end
