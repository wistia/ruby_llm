# frozen_string_literal: true

require 'spec_helper'

# Integration tests for Bedrock provider that actually exercise the full RubyLLM → Bedrock flow.
#
# To record VCR cassettes for these tests, run:
#   aws-vault exec wistia-development -- bundle exec rspec spec/ruby_llm/providers/bedrock/integration_spec.rb
#
# These tests verify:
# - Basic chat functionality (text messages, multi-turn conversations)
# - System instructions and custom prompts
# - Tool calling with RubyLLM::Tool classes
# - Streaming responses
# - Error handling
# - Token usage tracking
RSpec.describe 'Bedrock Provider Integration', :vcr do
  include_context 'with configured RubyLLM'

  let(:model_id) { 'bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0' }

  describe 'basic text chat' do
    it 'sends and receives text messages' do
      chat = RubyLLM.chat(model: model_id)
      response = chat.ask('What is 2 + 2? Answer with just the number.')

      expect(response).to be_a(RubyLLM::Message)
      expect(response.content).to include('4')
      expect(response.role).to eq(:assistant)
      expect(response.input_tokens).to be_positive
      expect(response.output_tokens).to be_positive
    end

    it 'handles simple questions' do
      chat = RubyLLM.chat(model: model_id)
      response = chat.ask('What color is the sky on a clear day? One word answer.')

      expect(response.content).to match(/blue/i)
      expect(response.role).to eq(:assistant)
    end
  end

  describe 'multi-turn conversation' do
    it 'maintains conversation context' do
      chat = RubyLLM.chat(model: model_id)

      first_response = chat.ask('My favorite number is 42.')
      expect(first_response.content).to be_present

      second_response = chat.ask('What is my favorite number?')
      expect(second_response.content).to include('42')
    end

    it 'builds message history correctly' do
      chat = RubyLLM.chat(model: model_id)

      chat.ask('Hello!')
      chat.ask('How are you?')

      expect(chat.messages.length).to eq(4) # 2 user messages + 2 assistant responses
      expect(chat.messages.map(&:role)).to eq([:user, :assistant, :user, :assistant])
    end
  end

  describe 'system messages' do
    it 'accepts system instructions' do
      chat = RubyLLM.chat(model: model_id)
      chat.with_instructions('You are a helpful assistant that always responds in haiku format (5-7-5 syllables).')

      response = chat.ask('Tell me about the moon.')

      expect(response.content).to be_present
      expect(response.role).to eq(:assistant)
      # Should have multiple lines (haiku format)
      expect(response.content.split("\n").length).to be >= 3
    end

    it 'follows custom instructions' do
      chat = RubyLLM.chat(model: model_id)
      chat.with_instructions('You must always end your responses with the phrase "END_MARKER_XYZ".')

      response = chat.ask('What is the capital of France?')

      expect(response.content).to match(/END_MARKER_XYZ/i)
    end
  end

  describe 'tool calling' do
    # Define a simple tool for testing
    class TestWeather < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock
      description 'Gets current weather for a location'
      param :latitude, desc: 'Latitude coordinate'
      param :longitude, desc: 'Longitude coordinate'

      def execute(latitude:, longitude:)
        "Weather at #{latitude}, #{longitude}: 72°F, sunny"
      end
    end

    it 'executes tools and returns results' do
      chat = RubyLLM.chat(model: model_id)
                    .with_tool(TestWeather)

      response = chat.ask("What's the weather at latitude 42.3601, longitude -71.0589?")

      expect(response.content).to match(/72|sunny/i)
      expect(response.role).to eq(:assistant)
    end

    it 'maintains conversation context with tool use' do
      chat = RubyLLM.chat(model: model_id)
                    .with_tool(TestWeather)

      first = chat.ask("What's the weather at 42.3601, -71.0589?")
      expect(first.content).to be_present

      second = chat.ask('Is it nice out?')
      expect(second.content).to match(/nice|sunny|good|pleasant/i)
    end
  end

  describe 'streaming responses' do
    it 'processes streaming chunks' do
      chat = RubyLLM.chat(model: model_id)
      chunks = []

      response = chat.ask('Count from 1 to 5.') do |chunk|
        chunks << chunk
      end

      expect(chunks).not_to be_empty
      expect(chunks.first).to be_a(RubyLLM::Chunk)
      expect(response).to be_a(RubyLLM::Message)
      expect(response.content).to match(/1.*2.*3.*4.*5/m)
    end

    it 'returns message with token usage after streaming' do
      chat = RubyLLM.chat(model: model_id)

      response = chat.ask('Say hello.') do |_chunk|
        # Process chunks
      end

      expect(response).to be_a(RubyLLM::Message)
      expect(response.content).to match(/hello/i)
      expect(response.input_tokens).to be_positive
      expect(response.output_tokens).to be_positive
    end
  end

  describe 'error handling' do
    it 'handles invalid model errors' do
      expect do
        chat = RubyLLM.chat(model: 'bedrock/invalid-model-name-12345')
        chat.ask('Hello')
      end.to raise_error(RubyLLM::BadRequestError)
    end

    it 'handles empty content by sending to API' do
      expect do
        chat = RubyLLM.chat(model: model_id)
        chat.ask('')
      end.to raise_error(RubyLLM::BadRequestError)
    end

    it 'raises configuration error when credentials are missing' do
      allow(RubyLLM.config).to receive(:bedrock_api_key).and_return(nil)
      allow(RubyLLM.config).to receive(:bedrock_secret_key).and_return(nil)

      expect do
        RubyLLM.chat(model: model_id)
      end.to raise_error(RubyLLM::ConfigurationError, /bedrock_api_key, bedrock_secret_key/)
    end
  end

  describe 'message formats' do
    let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }

    it 'handles content with image attachments' do
      chat = RubyLLM.chat(model: model_id)
      response = chat.ask('What logo do you see in this image? Answer in one word.', with: image_path)

      expect(response).to be_a(RubyLLM::Message)
      expect(response.content).to match(/ruby/i)
      expect(response.role).to eq(:assistant)

      # Verify the attachment was properly stored
      expect(chat.messages.first.content).to be_a(RubyLLM::Content)
      expect(chat.messages.first.content.attachments).not_to be_empty
      expect(chat.messages.first.content.attachments.first.filename).to eq('ruby.png')
      expect(chat.messages.first.content.attachments.first.mime_type).to eq('image/png')
    end
  end

  describe 'usage tracking' do
    it 'tracks token usage correctly' do
      chat = RubyLLM.chat(model: model_id)
      response = chat.ask('Hi')

      expect(response.input_tokens).to be > 0
      expect(response.output_tokens).to be > 0
    end

    it 'increases input tokens with conversation history' do
      chat = RubyLLM.chat(model: model_id)

      first = chat.ask('Hello')
      first_input = first.input_tokens

      second = chat.ask('Goodbye')
      second_input = second.input_tokens

      # Second turn should have more input tokens due to conversation history
      expect(second_input).to be > first_input
    end
  end
end
