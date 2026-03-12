# frozen_string_literal: true

require 'openssl'
require 'time'

module RubyLLM
  module Providers
    # AWS Bedrock Converse API integration.
    # This provider uses the Converse API which supports multiple model vendors.
    class BedrockConverse < Provider
      include BedrockConverse::Chat
      include BedrockConverse::Streaming
      include BedrockConverse::Models
      include BedrockConverse::Signing
      include BedrockConverse::Media

      def api_base
        "https://bedrock-runtime.#{@config.bedrock_region}.amazonaws.com"
      end

      def parse_error(response)
        return if response.body.empty?

        body = try_parse_json(response.body)
        case body
        when Hash
          body['message']
        when Array
          body.map do |part|
            part['message']
          end.join('. ')
        else
          body
        end
      end

      def sign_request(url, method: :post, payload: nil)
        signer = create_signer
        request = build_request(url, method:, payload:)
        signer.sign_request(request)
      end

      def create_signer
        Signing::Signer.new({
                              access_key_id: @config.bedrock_api_key,
                              secret_access_key: @config.bedrock_secret_key,
                              session_token: @config.bedrock_session_token,
                              region: @config.bedrock_region,
                              service: 'bedrock'
                            })
      end

      def build_request(url, method: :post, payload: nil)
        {
          connection: @connection,
          http_method: method,
          url: url || completion_url,
          body: payload ? JSON.generate(payload, ascii_only: false) : nil
        }
      end

      def build_headers(signature_headers = {}, streaming: false)
        accept_header = streaming ? 'application/vnd.amazon.eventstream' : 'application/json'

        base_headers = {
          'Content-Type' => 'application/json',
          'Accept' => accept_header
        }

        if use_bearer_token?
          base_headers.merge('Authorization' => "Bearer #{@config.bedrock_bearer_token}")
        else
          signature_headers.merge(base_headers)
        end
      end

      def use_bearer_token?
        !@config.bedrock_bearer_token.nil? && !@config.bedrock_bearer_token.empty?
      end

      def configured?
        # Region is always required
        return false unless @config.bedrock_region

        # Either bearer token OR aws credentials are required
        use_bearer_token? || (@config.bedrock_api_key && @config.bedrock_secret_key)
      end

      def ensure_configured!
        # Region is always required
        raise ConfigurationError, 'Missing configuration for BedrockConverse: bedrock_region' unless @config.bedrock_region

        # Either bearer token OR aws credentials are required
        has_bearer_token = use_bearer_token?
        has_aws_creds = @config.bedrock_api_key && @config.bedrock_secret_key

        return if has_bearer_token || has_aws_creds

        raise ConfigurationError,
              'Missing configuration for BedrockConverse: either bedrock_bearer_token OR ' \
              '(bedrock_api_key and bedrock_secret_key) required'
      end

      class << self
        def capabilities
          BedrockConverse::Capabilities
        end

        def configuration_options
          %i[bedrock_api_key bedrock_secret_key bedrock_region bedrock_session_token bedrock_bearer_token]
        end

        def configuration_requirements
          %i[bedrock_api_key bedrock_secret_key bedrock_region]
        end
      end
    end
  end
end
