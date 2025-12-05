# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Signing do
  let(:access_key_id) { 'AKIAIOSFODNN7EXAMPLE' }
  let(:secret_access_key) { 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY' }
  let(:session_token) { 'AQoDYXdzEJr...<remainder of session token>' }
  let(:region) { 'us-east-1' }
  let(:service) { 'bedrock' }

  describe RubyLLM::Providers::Bedrock::Signing::Credentials do
    describe '#initialize' do
      it 'accepts access_key_id and secret_access_key' do
        creds = described_class.new(
          access_key_id: access_key_id,
          secret_access_key: secret_access_key
        )

        expect(creds.access_key_id).to eq(access_key_id)
        expect(creds.secret_access_key).to eq(secret_access_key)
        expect(creds.session_token).to be_nil
      end

      it 'accepts optional session_token' do
        creds = described_class.new(
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          session_token: session_token
        )

        expect(creds.session_token).to eq(session_token)
      end

      it 'raises error when access_key_id is missing' do
        expect do
          described_class.new(secret_access_key: secret_access_key)
        end.to raise_error(ArgumentError, /expected both :access_key_id and :secret_access_key/)
      end

      it 'raises error when secret_access_key is missing' do
        expect do
          described_class.new(access_key_id: access_key_id)
        end.to raise_error(ArgumentError, /expected both :access_key_id and :secret_access_key/)
      end
    end

    describe '#set?' do
      it 'returns true when both keys are present and non-empty' do
        creds = described_class.new(
          access_key_id: access_key_id,
          secret_access_key: secret_access_key
        )

        expect(creds.set?).to be true
      end

      it 'returns false when access_key_id is empty' do
        creds = described_class.new(
          access_key_id: '',
          secret_access_key: secret_access_key
        )

        expect(creds.set?).to be false
      end

      it 'returns false when secret_access_key is empty' do
        creds = described_class.new(
          access_key_id: access_key_id,
          secret_access_key: ''
        )

        expect(creds.set?).to be false
      end
    end
  end

  describe RubyLLM::Providers::Bedrock::Signing::Signer do
    let(:signer) do
      described_class.new(
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        session_token: session_token,
        region: region,
        service: service
      )
    end

    describe '#initialize' do
      it 'accepts required credentials and configuration' do
        expect(signer.service).to eq(service)
        expect(signer.region).to eq(region)
        expect(signer.credentials_provider).to be_a(
          RubyLLM::Providers::Bedrock::Signing::StaticCredentialsProvider
        )
      end

      it 'raises error when service is missing' do
        expect do
          described_class.new(
            access_key_id: access_key_id,
            secret_access_key: secret_access_key,
            region: region
          )
        end.to raise_error(ArgumentError, /missing required option :service/)
      end

      it 'raises error when region is missing' do
        expect do
          described_class.new(
            access_key_id: access_key_id,
            secret_access_key: secret_access_key,
            service: service
          )
        end.to raise_error(RubyLLM::Providers::Bedrock::Signing::Errors::MissingRegionError)
      end

      it 'raises error when credentials are missing' do
        expect do
          described_class.new(
            region: region,
            service: service
          )
        end.to raise_error(RubyLLM::Providers::Bedrock::Signing::Errors::MissingCredentialsError)
      end

      it 'initializes unsigned_headers with defaults' do
        expect(signer.unsigned_headers).to include('authorization', 'x-amzn-trace-id', 'expect')
      end

      it 'allows custom unsigned_headers' do
        custom_signer = described_class.new(
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          region: region,
          service: service,
          unsigned_headers: ['custom-header']
        )

        expect(custom_signer.unsigned_headers).to include('custom-header', 'authorization')
      end
    end

    describe '#sign_request' do
      let(:url) { 'https://bedrock-runtime.us-east-1.amazonaws.com/model/test-model/converse' }
      let(:request) do
        {
          http_method: 'POST',
          url: url,
          headers: { 'content-type' => 'application/json' },
          body: '{"messages":[]}'
        }
      end

      it 'returns a Signature object' do
        signature = signer.sign_request(request)

        expect(signature).to be_a(RubyLLM::Providers::Bedrock::Signing::Signature)
      end

      it 'includes required AWS signature headers' do
        signature = signer.sign_request(request)

        expect(signature.headers).to include('host', 'x-amz-date', 'authorization')
      end

      it 'includes session token when provided' do
        signature = signer.sign_request(request)

        expect(signature.headers).to include('x-amz-security-token')
        expect(signature.headers['x-amz-security-token']).to eq(session_token)
      end

      it 'does not include session token when not provided' do
        signer_without_token = described_class.new(
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          region: region,
          service: service
        )

        signature = signer_without_token.sign_request(request)

        expect(signature.headers).not_to include('x-amz-security-token')
      end

      it 'includes content-sha256 header when apply_checksum_header is true' do
        signer_with_checksum = described_class.new(
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          region: region,
          service: service,
          apply_checksum_header: true
        )

        signature = signer_with_checksum.sign_request(request)

        expect(signature.headers).to include('x-amz-content-sha256')
      end

      it 'generates consistent signatures for identical requests' do
        # Freeze time to ensure consistent timestamps
        frozen_time = Time.utc(2025, 12, 5, 12, 0, 0)
        allow(Time).to receive(:now).and_return(frozen_time)

        sig1 = signer.sign_request(request)
        sig2 = signer.sign_request(request)

        expect(sig1.signature).to eq(sig2.signature)
      end

      it 'generates different signatures for different request bodies' do
        frozen_time = Time.utc(2025, 12, 5, 12, 0, 0)
        allow(Time).to receive(:now).and_return(frozen_time)

        request2 = request.merge(body: '{"messages":[{"role":"user","content":"test"}]}')

        sig1 = signer.sign_request(request)
        sig2 = signer.sign_request(request2)

        expect(sig1.signature).not_to eq(sig2.signature)
      end

      it 'populates debug fields in signature' do
        signature = signer.sign_request(request)

        expect(signature.canonical_request).not_to be_nil
        expect(signature.string_to_sign).not_to be_nil
        expect(signature.content_sha256).not_to be_nil
      end
    end
  end

  describe RubyLLM::Providers::Bedrock::Signing::UriUtils do
    describe '.uri_escape_path' do
      it 'escapes path components but preserves slashes' do
        result = described_class.uri_escape_path('/path/with spaces/file')
        expect(result).to eq('/path/with%20spaces/file')
      end

      it 'escapes special characters' do
        result = described_class.uri_escape_path('/path/with@special#chars')
        expect(result).to eq('/path/with%40special%23chars')
      end

      it 'preserves already escaped characters' do
        result = described_class.uri_escape_path('/path/already%20escaped')
        expect(result).to eq('/path/already%2520escaped')
      end
    end

    describe '.uri_escape' do
      it 'escapes spaces as %20 not +' do
        result = described_class.uri_escape('hello world')
        expect(result).to eq('hello%20world')
      end

      it 'preserves tildes unescaped' do
        result = described_class.uri_escape('~user')
        expect(result).to eq('~user')
      end

      it 'returns nil for nil input' do
        result = described_class.uri_escape(nil)
        expect(result).to be_nil
      end
    end

    describe '.normalize_path' do
      it 'removes redundant slashes and dots' do
        uri = URI.parse('https://example.com/path/./to/../resource')
        described_class.normalize_path(uri)
        expect(uri.path).to eq('/path/resource')
      end

      it 'preserves trailing slashes' do
        uri = URI.parse('https://example.com/path/to/dir/')
        described_class.normalize_path(uri)
        expect(uri.path).to eq('/path/to/dir/')
      end

      it 'handles empty path' do
        uri = URI.parse('https://example.com')
        described_class.normalize_path(uri)
        expect(uri.path).to eq('')
      end
    end

    describe '.host' do
      it 'returns host without port when using default port' do
        uri = URI.parse('https://example.com:443/path')
        result = described_class.host(uri)
        expect(result).to eq('example.com')
      end

      it 'returns host with port when using non-default port' do
        uri = URI.parse('https://example.com:8443/path')
        result = described_class.host(uri)
        expect(result).to eq('example.com:8443')
      end
    end
  end

  describe RubyLLM::Providers::Bedrock::Signing::CryptoUtils do
    describe '.sha256_hexdigest' do
      it 'returns correct SHA256 hex digest' do
        result = described_class.sha256_hexdigest('test')
        expected = '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08'
        expect(result).to eq(expected)
      end

      it 'handles empty string' do
        result = described_class.sha256_hexdigest('')
        expected = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        expect(result).to eq(expected)
      end
    end

    describe '.hmac' do
      it 'generates HMAC correctly' do
        result = described_class.hmac('key', 'message')
        expect(result).to be_a(String)
        expect(result.encoding).to eq(Encoding::ASCII_8BIT)
      end
    end

    describe '.hexhmac' do
      it 'generates hex HMAC correctly' do
        result = described_class.hexhmac('key', 'message')
        expect(result).to match(/\A[0-9a-f]{64}\z/)
      end
    end
  end

  describe RubyLLM::Providers::Bedrock::Signing::CanonicalRequest do
    let(:config) { RubyLLM::Providers::Bedrock::Signing::CanonicalRequestConfig.new }
    let(:url) { URI.parse('https://bedrock-runtime.us-east-1.amazonaws.com/model/test/converse') }
    let(:headers) do
      {
        'host' => 'bedrock-runtime.us-east-1.amazonaws.com',
        'x-amz-date' => '20251205T120000Z',
        'content-type' => 'application/json'
      }
    end
    let(:content_sha256) { 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' }

    let(:canonical_request) do
      described_class.new(
        http_method: 'POST',
        url: url,
        headers: headers,
        content_sha256: content_sha256,
        config: config
      )
    end

    describe '#to_s' do
      it 'generates canonical request string with correct format' do
        result = canonical_request.to_s
        lines = result.split("\n")

        expect(lines[0]).to eq('POST')
        expect(lines[1]).to start_with('/model')
        expect(lines[2]).to eq('') # Query string
        # Lines 3+ contain canonical headers (one per line)
        canonical_headers = lines[3...-2].join("\n") # All lines except method, path, query, signed_headers, and content_sha256
        expect(canonical_headers).to include('content-type:')
        expect(canonical_headers).to include('host:')
        expect(canonical_headers).to include('x-amz-date:')
      end

      it 'includes signed headers' do
        result = canonical_request.to_s
        expect(result).to include('content-type;host;x-amz-date')
      end

      it 'includes content SHA256' do
        result = canonical_request.to_s
        expect(result).to end_with(content_sha256)
      end
    end

    describe '#signed_headers' do
      it 'returns headers in alphabetical order' do
        result = canonical_request.signed_headers
        expect(result).to eq('content-type;host;x-amz-date')
      end

      it 'excludes unsigned headers' do
        config_with_unsigned = RubyLLM::Providers::Bedrock::Signing::CanonicalRequestConfig.new(
          unsigned_headers: Set.new(['content-type'])
        )

        canonical_request_with_unsigned = described_class.new(
          http_method: 'POST',
          url: url,
          headers: headers,
          content_sha256: content_sha256,
          config: config_with_unsigned
        )

        result = canonical_request_with_unsigned.signed_headers
        expect(result).to eq('host;x-amz-date')
        expect(result).not_to include('content-type')
      end
    end
  end

  describe 'Integration: Full signing workflow' do
    it 'successfully signs a typical Bedrock request' do
      signer = RubyLLM::Providers::Bedrock::Signing::Signer.new(
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        region: 'us-east-1',
        service: 'bedrock'
      )

      request = {
        http_method: 'POST',
        url: 'https://bedrock-runtime.us-east-1.amazonaws.com/model/claude-3-5-haiku/converse',
        headers: {
          'content-type' => 'application/json'
        },
        body: JSON.generate({ messages: [{ role: 'user', content: [{ text: 'Hello' }] }] })
      }

      signature = signer.sign_request(request)

      # Verify all required headers are present
      expect(signature.headers['authorization']).to start_with('AWS4-HMAC-SHA256 Credential=')
      expect(signature.headers['authorization']).to include('SignedHeaders=')
      expect(signature.headers['authorization']).to include('Signature=')
      expect(signature.headers['host']).to eq('bedrock-runtime.us-east-1.amazonaws.com')
      expect(signature.headers['x-amz-date']).to match(/\A\d{8}T\d{6}Z\z/)
    end
  end
end
