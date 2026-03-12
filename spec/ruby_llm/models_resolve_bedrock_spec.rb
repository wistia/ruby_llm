# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Models, '.resolve with Bedrock models' do
  include_context 'with configured RubyLLM'

  let(:config) { RubyLLM.config }

  # Ensure models are loaded from registry before running tests
  before do
    RubyLLM::Models.instance_variable_set(:@instance, nil)
    RubyLLM::Models.instance.load_from_json!
  end

  describe 'resolving Bedrock models' do
    context 'with fully qualified ARN-style model IDs' do
      let(:test_models) do
        [
          'us.anthropic.claude-haiku-4-5-20251001-v1:0',
          'us.amazon.nova-premier-v1:0',
          'us.meta.llama4-maverick-17b-instruct-v1:0',
          'us.deepseek.r1-v1:0'
        ]
      end

      it 'resolves with provider prefix format' do
        test_models.each do |model_id|
          model_info, provider_instance = described_class.resolve("bedrock/#{model_id}")

          expect(model_info).to be_a(RubyLLM::Model::Info)
          expect(model_info.id).to eq(model_id)
          expect(model_info.provider).to eq('bedrock')
          expect(provider_instance).to be_a(RubyLLM::Providers::Bedrock)
        end
      end

      it 'resolves with explicit provider parameter' do
        test_models.each do |model_id|
          model_info, provider_instance = described_class.resolve(model_id, provider: 'bedrock')

          expect(model_info).to be_a(RubyLLM::Model::Info)
          expect(model_info.id).to eq(model_id)
          expect(model_info.provider).to eq('bedrock')
          expect(provider_instance).to be_a(RubyLLM::Providers::Bedrock)
        end
      end

      it 'resolves with assume_exists flag' do
        test_models.each do |model_id|
          model_info, provider_instance = described_class.resolve(
            model_id,
            provider: 'bedrock',
            assume_exists: true
          )

          expect(model_info).to be_a(RubyLLM::Model::Info)
          expect(model_info.id).to eq(model_id)
          expect(model_info.provider).to eq('bedrock')
          expect(provider_instance).to be_a(RubyLLM::Providers::Bedrock)
        end
      end
    end

    context 'with registry-registered Bedrock models' do
      it 'finds models that exist in the registry' do
        # Claude Haiku 4.5 should be in the registry with full ARN ID
        model_id = 'us.anthropic.claude-haiku-4-5-20251001-v1:0'

        model_info, provider_instance = described_class.resolve(model_id, provider: 'bedrock')

        expect(model_info).to be_a(RubyLLM::Model::Info)
        expect(model_info.id).to eq(model_id)
        expect(provider_instance).to be_a(RubyLLM::Providers::Bedrock)
      end
    end

    context 'with cross-region model IDs' do
      let(:cross_region_models) do
        [
          'global.amazon.nova-2-lite-v1:0',
          'us.anthropic.claude-3-5-sonnet-20241022-v2:0'
        ]
      end

      it 'resolves cross-region model IDs' do
        cross_region_models.each do |model_id|
          model_info, provider_instance = described_class.resolve("bedrock/#{model_id}")

          expect(model_info).to be_a(RubyLLM::Model::Info)
          expect(model_info.id).to eq(model_id)
          expect(model_info.provider).to eq('bedrock')
          expect(provider_instance).to be_a(RubyLLM::Providers::Bedrock)
        end
      end
    end

    context 'error handling' do
      it 'raises ModelNotFoundError when provider is unknown' do
        # When provider doesn't exist, Models.find raises ModelNotFoundError first
        expect do
          described_class.resolve('some-model', provider: 'nonexistent')
        end.to raise_error(RubyLLM::ModelNotFoundError, /Unknown model/)
      end

      it 'raises error when model not found and provider is not Bedrock' do
        expect do
          described_class.resolve('nonexistent-model-xyz', provider: 'openai')
        end.to raise_error(RubyLLM::ModelNotFoundError)
      end

      it 'raises error when assume_exists is true without provider' do
        expect do
          described_class.resolve('some-model', assume_exists: true)
        end.to raise_error(ArgumentError, /Provider must be specified/)
      end
    end

    context 'comparison with other providers' do
      it 'resolves OpenAI models from registry' do
        model_info, provider_instance = described_class.resolve('gpt-4o', provider: 'openai')

        expect(model_info).to be_a(RubyLLM::Model::Info)
        expect(model_info.id).to eq('gpt-4o')
        expect(model_info.provider).to eq('openai')
        expect(provider_instance).to be_a(RubyLLM::Providers::OpenAI)
      end

      it 'requires exact match for non-Bedrock providers' do
        expect do
          described_class.resolve('unknown-openai-model', provider: 'openai')
        end.to raise_error(RubyLLM::ModelNotFoundError)
      end
    end
  end
end
