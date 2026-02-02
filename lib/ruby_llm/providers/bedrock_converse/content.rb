# frozen_string_literal: true

module RubyLLM
  module Providers
    class BedrockConverse
      # Helper class for building content blocks with cache points for AWS Bedrock Converse API.
      # Bedrock uses cachePoint blocks instead of Anthropic's cache_control format.
      #
      # @example Cache system instructions with default TTL
      #   content = BedrockConverse::Content.new("System prompt", cache: true)
      #
      # @example Cache with explicit TTL
      #   content = BedrockConverse::Content.new("System prompt", ttl: '1h')
      class Content
        VALID_TTLS = %w[5m 1h].freeze

        def self.new(text = nil, cache: false, ttl: nil, parts: nil)
          payload = if parts
                      Array(parts)
                    else
                      raise ArgumentError, 'text or parts required' if text.nil?

                      blocks = [{ text: text }]
                      blocks << { cachePoint: { type: 'default', ttl: ttl || '5m' } } if cache || ttl
                      blocks
                    end
          RubyLLM::Content::Raw.new(payload)
        end
      end
    end
  end
end
