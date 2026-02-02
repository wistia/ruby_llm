# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::BedrockConverse::Content do
  describe '.new' do
    it 'creates a Raw content object with text only when cache is false' do
      result = described_class.new('Hello, world!')

      expect(result).to be_a(RubyLLM::Content::Raw)
      expect(result.value).to eq([{ text: 'Hello, world!' }])
    end

    it 'creates a Raw content object with text and cachePoint when cache is true' do
      result = described_class.new('System prompt', cache: true)

      expect(result).to be_a(RubyLLM::Content::Raw)
      expect(result.value).to eq([
                                   { text: 'System prompt' },
                                   { cachePoint: { type: 'default', ttl: '5m' } }
                                 ])
    end

    it 'creates a Raw content object with text and cachePoint when ttl is provided' do
      result = described_class.new('System prompt', ttl: '1h')

      expect(result).to be_a(RubyLLM::Content::Raw)
      expect(result.value).to eq([
                                   { text: 'System prompt' },
                                   { cachePoint: { type: 'default', ttl: '1h' } }
                                 ])
    end

    it 'uses provided ttl over default when both cache and ttl are set' do
      result = described_class.new('System prompt', cache: true, ttl: '1h')

      expect(result).to be_a(RubyLLM::Content::Raw)
      expect(result.value).to eq([
                                   { text: 'System prompt' },
                                   { cachePoint: { type: 'default', ttl: '1h' } }
                                 ])
    end

    it 'uses default 5m ttl when cache is true and no ttl provided' do
      result = described_class.new('System prompt', cache: true)

      expect(result.value[1][:cachePoint][:ttl]).to eq('5m')
    end

    it 'accepts parts directly' do
      parts = [
        { text: 'Part 1' },
        { text: 'Part 2' },
        { cachePoint: { type: 'default', ttl: '5m' } }
      ]
      result = described_class.new(parts: parts)

      expect(result).to be_a(RubyLLM::Content::Raw)
      expect(result.value).to eq(parts)
    end

    it 'raises ArgumentError when neither text nor parts provided' do
      expect { described_class.new }.to raise_error(ArgumentError, 'text or parts required')
    end

    it 'raises ArgumentError when text is nil and parts is nil' do
      expect { described_class.new(nil) }.to raise_error(ArgumentError, 'text or parts required')
    end

    it 'ignores text when parts is provided' do
      parts = [{ text: 'From parts' }]
      result = described_class.new('From text', parts: parts)

      expect(result.value).to eq(parts)
    end

    it 'accepts parts as an array' do
      parts = [{ text: 'Single part' }]
      result = described_class.new(parts: parts)

      expect(result.value).to eq([{ text: 'Single part' }])
    end
  end

  describe 'VALID_TTLS constant' do
    it 'includes valid TTL values' do
      expect(described_class::VALID_TTLS).to contain_exactly('5m', '1h')
    end
  end
end
