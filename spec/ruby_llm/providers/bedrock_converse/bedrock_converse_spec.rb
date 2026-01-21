# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::BedrockConverse do
  let(:config) do
    config = RubyLLM::Configuration.new
    config.bedrock_api_key = 'AKIAIOSFODNN7EXAMPLE'
    config.bedrock_secret_key = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
    config.bedrock_region = 'us-east-1'
    config
  end

  let(:connection) { instance_double(Faraday::Connection) }

  let(:bedrock_converse_instance) do
    instance = described_class.new(config)
    allow(instance).to receive(:connection).and_return(connection)
    instance
  end

  describe '#api_base' do
    it 'constructs URL with us-east-1 region' do
      config = RubyLLM::Configuration.new
      config.bedrock_api_key = 'key'
      config.bedrock_secret_key = 'secret'
      config.bedrock_region = 'us-east-1'
      instance = described_class.new(config)

      expect(instance.api_base).to eq('https://bedrock-runtime.us-east-1.amazonaws.com')
    end

    it 'constructs URL with us-west-2 region' do
      config = RubyLLM::Configuration.new
      config.bedrock_api_key = 'key'
      config.bedrock_secret_key = 'secret'
      config.bedrock_region = 'us-west-2'
      instance = described_class.new(config)

      expect(instance.api_base).to eq('https://bedrock-runtime.us-west-2.amazonaws.com')
    end

    it 'constructs URL with eu-west-1 region' do
      config = RubyLLM::Configuration.new
      config.bedrock_api_key = 'key'
      config.bedrock_secret_key = 'secret'
      config.bedrock_region = 'eu-west-1'
      instance = described_class.new(config)

      expect(instance.api_base).to eq('https://bedrock-runtime.eu-west-1.amazonaws.com')
    end

    it 'constructs URL with ap-southeast-1 region' do
      config = RubyLLM::Configuration.new
      config.bedrock_api_key = 'key'
      config.bedrock_secret_key = 'secret'
      config.bedrock_region = 'ap-southeast-1'
      instance = described_class.new(config)

      expect(instance.api_base).to eq('https://bedrock-runtime.ap-southeast-1.amazonaws.com')
    end

    it 'constructs URL with custom region' do
      config = RubyLLM::Configuration.new
      config.bedrock_api_key = 'key'
      config.bedrock_secret_key = 'secret'
      config.bedrock_region = 'custom-region-1'
      instance = described_class.new(config)

      expect(instance.api_base).to eq('https://bedrock-runtime.custom-region-1.amazonaws.com')
    end

    it 'uses bedrock-runtime prefix consistently' do
      config = RubyLLM::Configuration.new
      config.bedrock_api_key = 'key'
      config.bedrock_secret_key = 'secret'
      config.bedrock_region = 'any-region'
      instance = described_class.new(config)

      expect(instance.api_base).to start_with('https://bedrock-runtime.')
    end

    it 'ends with amazonaws.com domain' do
      config = RubyLLM::Configuration.new
      config.bedrock_api_key = 'key'
      config.bedrock_secret_key = 'secret'
      config.bedrock_region = 'us-east-1'
      instance = described_class.new(config)

      expect(instance.api_base).to end_with('.amazonaws.com')
    end
  end

  describe '#parse_error' do
    context 'with empty response body' do
      it 'returns nil' do
        response = instance_double(Faraday::Response, body: '')

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to be_nil
      end
    end

    context 'with Hash error body' do
      it 'extracts message from Hash' do
        response = instance_double(
          Faraday::Response,
          body: '{"message": "Access denied"}'
        )

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to eq('Access denied')
      end

      it 'returns nil when message key is missing' do
        response = instance_double(
          Faraday::Response,
          body: '{"error": "Some error", "code": 403}'
        )

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to be_nil
      end

      it 'handles nested error structure' do
        response = instance_double(
          Faraday::Response,
          body: '{"message": "Invalid request", "details": {"field": "model"}}'
        )

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to eq('Invalid request')
      end
    end

    context 'with Array error body' do
      it 'joins messages from multiple errors' do
        response = instance_double(
          Faraday::Response,
          body: '[{"message": "Error 1"}, {"message": "Error 2"}]'
        )

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to eq('Error 1. Error 2')
      end

      it 'handles array with single error' do
        response = instance_double(
          Faraday::Response,
          body: '[{"message": "Single error"}]'
        )

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to eq('Single error')
      end

      it 'skips errors without message key' do
        response = instance_double(
          Faraday::Response,
          body: '[{"message": "Error 1"}, {"error": "No message"}, {"message": "Error 2"}]'
        )

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to eq('Error 1. . Error 2')
      end

      it 'handles empty array' do
        response = instance_double(
          Faraday::Response,
          body: '[]'
        )

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to eq('')
      end
    end

    context 'with String error body' do
      it 'returns the string directly' do
        response = instance_double(
          Faraday::Response,
          body: 'Plain text error message'
        )

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to eq('Plain text error message')
      end

      it 'handles multiline string' do
        error_text = "Error occurred\nDetails: invalid input\nPlease try again"
        response = instance_double(
          Faraday::Response,
          body: error_text
        )

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to eq(error_text)
      end
    end

    context 'with invalid JSON' do
      it 'returns the raw body when JSON parsing fails' do
        response = instance_double(
          Faraday::Response,
          body: '{invalid json content'
        )

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to eq('{invalid json content')
      end

      it 'handles malformed JSON gracefully' do
        response = instance_double(
          Faraday::Response,
          body: '{"message": "incomplete'
        )

        result = bedrock_converse_instance.parse_error(response)

        expect(result).to eq('{"message": "incomplete')
      end
    end
  end

  describe '#build_request' do
    let(:url) { 'https://bedrock-runtime.us-east-1.amazonaws.com/model/invoke' }

    context 'with POST method' do
      it 'builds request with default POST method' do
        payload = { messages: [{ role: 'user', content: 'Hello' }] }

        request = bedrock_converse_instance.build_request(url, payload: payload)

        expect(request[:http_method]).to eq(:post)
        expect(request[:url]).to eq(url)
        expect(request[:body]).to be_a(String)
        expect(JSON.parse(request[:body])).to eq(JSON.parse(payload.to_json))
      end

      it 'explicitly sets POST method when specified' do
        payload = { test: 'data' }

        request = bedrock_converse_instance.build_request(url, method: :post, payload: payload)

        expect(request[:http_method]).to eq(:post)
      end

      it 'includes connection in request' do
        payload = { data: 'value' }

        request = bedrock_converse_instance.build_request(url, payload: payload)

        expect(request[:connection]).to be_a(RubyLLM::Connection)
      end
    end

    context 'with GET method' do
      it 'builds request with GET method' do
        request = bedrock_converse_instance.build_request(url, method: :get)

        expect(request[:http_method]).to eq(:get)
        expect(request[:url]).to eq(url)
        expect(request[:body]).to be_nil
      end

      it 'omits body for GET requests' do
        request = bedrock_converse_instance.build_request(url, method: :get, payload: nil)

        expect(request[:body]).to be_nil
      end
    end

    context 'with PUT method' do
      it 'builds request with PUT method' do
        payload = { update: 'data' }

        request = bedrock_converse_instance.build_request(url, method: :put, payload: payload)

        expect(request[:http_method]).to eq(:put)
        expect(request[:body]).to include('"update":"data"')
      end
    end

    context 'with DELETE method' do
      it 'builds request with DELETE method' do
        request = bedrock_converse_instance.build_request(url, method: :delete)

        expect(request[:http_method]).to eq(:delete)
      end
    end

    context 'with different payloads' do
      it 'handles nil payload' do
        request = bedrock_converse_instance.build_request(url, payload: nil)

        expect(request[:body]).to be_nil
      end

      it 'serializes simple Hash payload' do
        payload = { key: 'value' }

        request = bedrock_converse_instance.build_request(url, payload: payload)

        expect(request[:body]).to eq('{"key":"value"}')
      end

      it 'serializes nested Hash payload' do
        payload = {
          messages: [{ role: 'user', content: 'test' }],
          inferenceConfig: { maxTokens: 1024 }
        }

        request = bedrock_converse_instance.build_request(url, payload: payload)

        parsed_body = JSON.parse(request[:body])
        expect(parsed_body['messages']).to be_an(Array)
        expect(parsed_body['inferenceConfig']['maxTokens']).to eq(1024)
      end

      it 'serializes payload with Array values' do
        payload = { items: [1, 2, 3], tags: ['a', 'b'] }

        request = bedrock_converse_instance.build_request(url, payload: payload)

        parsed_body = JSON.parse(request[:body])
        expect(parsed_body['items']).to eq([1, 2, 3])
        expect(parsed_body['tags']).to eq(['a', 'b'])
      end

      it 'handles payload with special characters' do
        payload = { text: "Hello\nWorld\t\"quoted\"" }

        request = bedrock_converse_instance.build_request(url, payload: payload)

        parsed_body = JSON.parse(request[:body])
        expect(parsed_body['text']).to eq("Hello\nWorld\t\"quoted\"")
      end

      it 'handles payload with Unicode characters' do
        payload = { text: 'こんにちは 🌍' }

        request = bedrock_converse_instance.build_request(url, payload: payload)

        # Should not escape unicode with ascii_only: false
        expect(request[:body]).to include('こんにちは')
        expect(request[:body]).to include('🌍')
      end

      it 'handles empty Hash payload' do
        payload = {}

        request = bedrock_converse_instance.build_request(url, payload: payload)

        expect(request[:body]).to eq('{}')
      end
    end

    context 'with URL handling' do
      it 'uses provided URL' do
        custom_url = 'https://custom.amazonaws.com/endpoint'

        request = bedrock_converse_instance.build_request(custom_url, payload: {})

        expect(request[:url]).to eq(custom_url)
      end

      it 'falls back to completion_url when URL is nil' do
        allow(bedrock_converse_instance).to receive(:completion_url).and_return('https://fallback.url')

        request = bedrock_converse_instance.build_request(nil, payload: {})

        expect(request[:url]).to eq('https://fallback.url')
      end
    end
  end

  describe '#build_headers' do
    let(:signature_headers) do
      {
        'Authorization' => 'AWS4-HMAC-SHA256 Credential=...',
        'X-Amz-Date' => '20231201T120000Z',
        'X-Amz-Security-Token' => 'token123'
      }
    end

    context 'with non-streaming request' do
      it 'builds headers with JSON accept type' do
        headers = bedrock_converse_instance.build_headers(signature_headers, streaming: false)

        expect(headers['Accept']).to eq('application/json')
        expect(headers['Content-Type']).to eq('application/json')
      end

      it 'merges signature headers' do
        headers = bedrock_converse_instance.build_headers(signature_headers, streaming: false)

        expect(headers['Authorization']).to eq('AWS4-HMAC-SHA256 Credential=...')
        expect(headers['X-Amz-Date']).to eq('20231201T120000Z')
        expect(headers['X-Amz-Security-Token']).to eq('token123')
      end

      it 'includes all required headers' do
        headers = bedrock_converse_instance.build_headers(signature_headers, streaming: false)

        expect(headers.keys).to include('Content-Type', 'Accept', 'Authorization', 'X-Amz-Date')
      end
    end

    context 'with streaming request' do
      it 'builds headers with eventstream accept type' do
        headers = bedrock_converse_instance.build_headers(signature_headers, streaming: true)

        expect(headers['Accept']).to eq('application/vnd.amazon.eventstream')
        expect(headers['Content-Type']).to eq('application/json')
      end

      it 'merges signature headers for streaming' do
        headers = bedrock_converse_instance.build_headers(signature_headers, streaming: true)

        expect(headers['Authorization']).to eq('AWS4-HMAC-SHA256 Credential=...')
        expect(headers['X-Amz-Date']).to eq('20231201T120000Z')
      end

      it 'uses correct eventstream mime type' do
        headers = bedrock_converse_instance.build_headers(signature_headers, streaming: true)

        expect(headers['Accept']).to eq('application/vnd.amazon.eventstream')
      end
    end

    context 'with empty signature headers' do
      it 'still includes Content-Type and Accept' do
        headers = bedrock_converse_instance.build_headers({}, streaming: false)

        expect(headers['Content-Type']).to eq('application/json')
        expect(headers['Accept']).to eq('application/json')
      end
    end

    context 'with additional signature headers' do
      it 'preserves custom headers from signature' do
        custom_signature_headers = signature_headers.merge(
          'X-Custom-Header' => 'custom-value',
          'X-Request-Id' => 'req-123'
        )

        headers = bedrock_converse_instance.build_headers(custom_signature_headers, streaming: false)

        expect(headers['X-Custom-Header']).to eq('custom-value')
        expect(headers['X-Request-Id']).to eq('req-123')
      end
    end

    context 'header precedence' do
      it 'does not override Content-Type from signature headers' do
        headers_with_content_type = signature_headers.merge('Content-Type' => 'application/xml')

        headers = bedrock_converse_instance.build_headers(headers_with_content_type, streaming: false)

        # build_headers should merge and the last merge wins
        expect(headers['Content-Type']).to eq('application/json')
      end

      it 'does not override Accept from signature headers' do
        headers_with_accept = signature_headers.merge('Accept' => 'text/plain')

        headers = bedrock_converse_instance.build_headers(headers_with_accept, streaming: false)

        # build_headers should merge and the last merge wins
        expect(headers['Accept']).to eq('application/json')
      end
    end

    it 'always sets Content-Type to application/json' do
      headers_streaming = bedrock_converse_instance.build_headers(signature_headers, streaming: true)
      headers_non_streaming = bedrock_converse_instance.build_headers(signature_headers, streaming: false)

      expect(headers_streaming['Content-Type']).to eq('application/json')
      expect(headers_non_streaming['Content-Type']).to eq('application/json')
    end
  end

  describe '.capabilities' do
    it 'returns BedrockConverse::Capabilities' do
      expect(described_class.capabilities).to eq(RubyLLM::Providers::BedrockConverse::Capabilities)
    end
  end

  describe '.configuration_requirements' do
    it 'returns required configuration keys' do
      requirements = described_class.configuration_requirements

      expect(requirements).to contain_exactly(
        :bedrock_api_key,
        :bedrock_secret_key,
        :bedrock_region
      )
    end

    it 'returns an array' do
      expect(described_class.configuration_requirements).to be_an(Array)
    end

    it 'has exactly 3 requirements' do
      expect(described_class.configuration_requirements.length).to eq(3)
    end
  end
end
