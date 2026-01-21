# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::BedrockConverse::Streaming::Base do
  # Create a test class that includes the Base module
  let(:streaming_provider) do
    klass = Class.new do
      include RubyLLM::Providers::BedrockConverse::Streaming::Base

      attr_accessor :model_id

      def initialize
        @model_id = 'anthropic.claude-3-5-haiku-20241022-v1:0'
      end

      # Mock sign_request method
      def sign_request(_url, payload:)
        Struct.new(:headers).new({ 'authorization' => 'mock-signature' })
      end

      # Mock build_headers method
      def build_headers(signature_headers, streaming: false)
        {
          'content-type' => 'application/json',
          'x-amz-streaming' => streaming.to_s
        }.merge(signature_headers)
      end
    end
    klass.new
  end

  describe '#stream_url' do
    it 'returns the correct streaming endpoint' do
      url = streaming_provider.stream_url

      expect(url).to eq('model/anthropic.claude-3-5-haiku-20241022-v1:0/converse-stream')
    end

    it 'includes the model_id in the URL' do
      streaming_provider.model_id = 'amazon.nova-micro-v1:0'
      url = streaming_provider.stream_url

      expect(url).to include('amazon.nova-micro-v1:0')
    end
  end

  describe '#handle_stream' do
    it 'returns a proc that processes chunks' do
      handler = streaming_provider.handle_stream { |_chunk| }

      expect(handler).to be_a(Proc)
    end

    it 'calls process_chunk for successful responses' do
      handler = streaming_provider.handle_stream { |_chunk| }

      # Mock environment with status 200
      env = Struct.new(:status).new(200)

      expect(streaming_provider).to receive(:process_chunk).with('chunk data')

      handler.call('chunk data', nil, env)
    end

    it 'processes chunk when env is nil' do
      handler = streaming_provider.handle_stream { |_chunk| }

      expect(streaming_provider).to receive(:process_chunk).with('chunk data')

      handler.call('chunk data', nil, nil)
    end

    it 'yields processed chunks to the block' do
      yielded = []
      handler = streaming_provider.handle_stream { |chunk| yielded << chunk }

      # Create a valid streaming chunk
      json_data = { 'delta' => { 'text' => 'Test' } }
      message = create_bedrock_message(json_data)

      env = Struct.new(:status).new(200)
      handler.call(message, nil, env)

      expect(yielded).not_to be_empty
    end

    it 'accumulates multiple chunks in buffer' do
      handler = streaming_provider.handle_stream { |_chunk| }

      env = Struct.new(:status).new(200)

      # Simulate multiple chunk calls
      expect { handler.call('first', nil, env) }.not_to raise_error
      expect { handler.call('second', nil, env) }.not_to raise_error
      expect { handler.call('third', nil, env) }.not_to raise_error
    end
  end

  describe 'integration: processing realistic chunks' do
    it 'processes a complete streaming message' do
      json_data = { 'delta' => { 'text' => 'Hello, world!' } }
      message = create_bedrock_message(json_data)

      yielded = []
      handler = streaming_provider.handle_stream { |chunk| yielded << chunk }

      env = Struct.new(:status).new(200)
      handler.call(message, nil, env)

      expect(yielded.length).to eq(1)
      expect(yielded.first.content).to eq('Hello, world!')
    end

    it 'processes multiple streaming messages' do
      msg1 = create_bedrock_message({ 'delta' => { 'text' => 'First ' } })
      msg2 = create_bedrock_message({ 'delta' => { 'text' => 'Second' } })

      yielded = []
      handler = streaming_provider.handle_stream { |chunk| yielded << chunk }

      env = Struct.new(:status).new(200)
      handler.call(msg1, nil, env)
      handler.call(msg2, nil, env)

      expect(yielded.length).to eq(2)
      expect(yielded.map(&:content)).to eq(['First ', 'Second'])
    end

    it 'processes tool call message' do
      tool_data = {
        'start' => {
          'toolUse' => {
            'toolUseId' => 'tool_123',
            'name' => 'get_weather'
          }
        }
      }
      message = create_bedrock_message(tool_data)

      yielded = []
      handler = streaming_provider.handle_stream { |chunk| yielded << chunk }

      env = Struct.new(:status).new(200)
      handler.call(message, nil, env)

      expect(yielded.length).to eq(1)
      expect(yielded.first.tool_calls).not_to be_nil
      expect(yielded.first.tool_calls['tool_123'].name).to eq('get_weather')
    end

    it 'processes usage information' do
      usage_data = {
        'usage' => {
          'inputTokens' => 50,
          'outputTokens' => 25
        }
      }
      message = create_bedrock_message(usage_data)

      yielded = []
      handler = streaming_provider.handle_stream { |chunk| yielded << chunk }

      env = Struct.new(:status).new(200)
      handler.call(message, nil, env)

      # Usage-only chunks typically don't yield content
      # But the handler should process without error
      expect { handler.call(message, nil, env) }.not_to raise_error
    end
  end

  # Helper method to create a properly formatted Bedrock streaming message
  def create_bedrock_message(json_data)
    json_payload = JSON.generate(json_data)
    total_length = 12 + 20 + json_payload.bytesize + 4 # prelude + headers + payload + CRC
    headers_length = 20

    prelude = [total_length, headers_length, 0].pack('NNN')
    headers = 'h' * headers_length
    crc = [0].pack('N')

    prelude + headers + json_payload + crc
  end
end
