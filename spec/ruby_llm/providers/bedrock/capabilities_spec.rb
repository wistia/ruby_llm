# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Capabilities do
  describe '.model_family' do
    context 'with Claude models' do
      it 'identifies Claude 3 Haiku' do
        expect(described_class.model_family('anthropic.claude-3-haiku-20240307-v1:0')).to eq(:claude3_haiku)
        expect(described_class.model_family('us.anthropic.claude-3-haiku-20240307-v1:0')).to eq(:claude3_haiku)
      end

      it 'identifies Claude 3.5 Haiku' do
        expect(described_class.model_family('anthropic.claude-3-5-haiku-20241022-v1:0')).to eq(:claude3_5_haiku)
        expect(described_class.model_family('us.anthropic.claude-3-5-haiku-20241022-v1:0')).to eq(:claude3_5_haiku)
      end

      it 'identifies Claude 3.5 Sonnet' do
        expect(described_class.model_family('anthropic.claude-3-5-sonnet-20240620-v1:0')).to eq(:claude3_5_sonnet)
        expect(described_class.model_family('eu.anthropic.claude-3-5-sonnet-20241022-v2:0')).to eq(:claude3_5_sonnet)
      end

      it 'identifies Claude 3.7 Sonnet' do
        expect(described_class.model_family('anthropic.claude-3-7-sonnet-20250219-v1:0')).to eq(:claude3_7_sonnet)
      end

      it 'identifies Claude 4 Sonnet' do
        expect(described_class.model_family('anthropic.claude-sonnet-4-20250514-v1:0')).to eq(:claude4_sonnet)
      end

      it 'identifies Claude 4 Opus' do
        expect(described_class.model_family('anthropic.claude-opus-4-20250514-v1:0')).to eq(:claude4_opus)
      end

      it 'identifies Claude 4.1 Opus' do
        expect(described_class.model_family('anthropic.claude-opus-4-1-20250805-v1:0')).to eq(:claude4_1_opus)
        expect(described_class.model_family('us.anthropic.claude-opus-4-1-20250805-v1:0')).to eq(:claude4_1_opus)
      end

      it 'identifies Claude 4.5 models' do
        expect(described_class.model_family('anthropic.claude-sonnet-4-5-20251101-v1:0')).to eq(:claude4_5_sonnet)
        expect(described_class.model_family('anthropic.claude-opus-4-5-20251101-v1:0')).to eq(:claude4_5_opus)
        expect(described_class.model_family('anthropic.claude-haiku-4-5-20251101-v1:0')).to eq(:claude4_5_haiku)
      end
    end

    context 'with Amazon Nova models' do
      it 'identifies Nova Micro' do
        expect(described_class.model_family('amazon.nova-micro-v1:0')).to eq(:nova_micro)
        expect(described_class.model_family('us.amazon.nova-micro-v1:0')).to eq(:nova_micro)
      end

      it 'identifies Nova Lite' do
        expect(described_class.model_family('amazon.nova-lite-v1:0')).to eq(:nova_lite)
      end

      it 'identifies Nova Pro' do
        expect(described_class.model_family('amazon.nova-pro-v1:0')).to eq(:nova_pro)
      end

      it 'identifies Nova Premier' do
        expect(described_class.model_family('amazon.nova-premier-v1:0')).to eq(:nova_premier)
      end

      it 'identifies Nova 2 Lite' do
        expect(described_class.model_family('amazon.nova-2-lite-v1:0')).to eq(:nova_2_lite)
      end
    end

    context 'with Meta Llama models' do
      it 'identifies Llama 4 Maverick' do
        expect(described_class.model_family('meta.llama4-maverick-70b-instruct-v1:0')).to eq(:llama4_maverick)
      end

      it 'identifies Llama 4 Scout' do
        expect(described_class.model_family('meta.llama4-scout-17b-instruct-v1:0')).to eq(:llama4_scout)
      end
    end

    context 'with other provider models' do
      it 'identifies OpenAI models' do
        expect(described_class.model_family('openai.gpt-oss-120b-20250130-v1:0')).to eq(:gpt_oss_120b)
        expect(described_class.model_family('openai.gpt-oss-20b-20250130-v1:0')).to eq(:gpt_oss_20b)
      end

      it 'identifies Qwen models' do
        expect(described_class.model_family('qwen.qwen3-coder-480b-a22b')).to eq(:qwen3_coder_480b)
        expect(described_class.model_family('qwen.qwen3-vl-235b-a22b')).to eq(:qwen3_vl_235b)
        expect(described_class.model_family('qwen.qwen3-next-80b-a22b')).to eq(:qwen3_next_80b)
      end

      it 'identifies Minimax models' do
        expect(described_class.model_family('minimax.minimax-m2')).to eq(:minimax_m2)
      end

      it 'identifies DeepSeek models' do
        expect(described_class.model_family('deepseek.r1-v1:0')).to eq(:deepseek_r1)
        expect(described_class.model_family('deepseek.v3-v1:0')).to eq(:deepseek_v3)
      end

      it 'identifies Google Gemma models' do
        expect(described_class.model_family('google.gemma-3-27b-it')).to eq(:gemma3_27b)
        expect(described_class.model_family('google.gemma-3-12b-it')).to eq(:gemma3_12b)
        expect(described_class.model_family('google.gemma-3-4b-it')).to eq(:gemma3_4b)
      end

      it 'identifies Kimi models' do
        expect(described_class.model_family('moonshot.kimi-k2-thinking')).to eq(:kimi_k2_thinking)
      end

      it 'identifies Mistral models' do
        expect(described_class.model_family('mistral.mistral-large-3-675b-instruct')).to eq(:mistral_large_3)
        expect(described_class.model_family('mistral.pixtral-large-2502-128k-instruct')).to eq(:pixtral_large_2502)
      end
    end

    context 'with unknown models' do
      it 'returns :other for unrecognized model IDs' do
        expect(described_class.model_family('unknown.model-id')).to eq(:other)
        expect(described_class.model_family('future.unreleased-model')).to eq(:other)
      end
    end
  end

  describe '.context_window_for' do
    it 'returns correct context window for Claude models' do
      expect(described_class.context_window_for('anthropic.claude-3-haiku-20240307-v1:0')).to eq(200_000)
      expect(described_class.context_window_for('anthropic.claude-3-5-sonnet-20240620-v1:0')).to eq(200_000)
      expect(described_class.context_window_for('anthropic.claude-opus-4-1-20250805-v1:0')).to eq(200_000)
    end

    it 'returns correct context window for Nova models' do
      expect(described_class.context_window_for('amazon.nova-micro-v1:0')).to eq(128_000)
      expect(described_class.context_window_for('amazon.nova-lite-v1:0')).to eq(300_000)
      expect(described_class.context_window_for('amazon.nova-premier-v1:0')).to eq(1_000_000)
    end

    it 'returns correct context window for Llama models' do
      expect(described_class.context_window_for('meta.llama4-maverick-70b-instruct-v1:0')).to eq(1_000_000)
      expect(described_class.context_window_for('meta.llama4-scout-17b-instruct-v1:0')).to eq(3_500_000)
    end

    it 'returns default context window for unknown models' do
      expect(described_class.context_window_for('unknown.model')).to eq(128_000)
    end
  end

  describe '.max_tokens_for' do
    it 'returns correct max tokens for Claude 3 models' do
      expect(described_class.max_tokens_for('anthropic.claude-3-haiku-20240307-v1:0')).to eq(4_096)
      expect(described_class.max_tokens_for('anthropic.claude-3-5-haiku-20241022-v1:0')).to eq(8_192)
      expect(described_class.max_tokens_for('anthropic.claude-3-5-sonnet-20240620-v1:0')).to eq(8_192)
    end

    it 'returns correct max tokens for Claude 4+ models' do
      expect(described_class.max_tokens_for('anthropic.claude-3-7-sonnet-20250219-v1:0')).to eq(64_000)
      expect(described_class.max_tokens_for('anthropic.claude-opus-4-1-20250805-v1:0')).to eq(32_000)
      expect(described_class.max_tokens_for('anthropic.claude-sonnet-4-5-20251101-v1:0')).to eq(64_000)
    end

    it 'returns correct max tokens for Nova models' do
      expect(described_class.max_tokens_for('amazon.nova-micro-v1:0')).to eq(10_000)
      expect(described_class.max_tokens_for('amazon.nova-premier-v1:0')).to eq(10_000)
    end

    it 'returns default max tokens for unknown models' do
      expect(described_class.max_tokens_for('unknown.model')).to eq(4_096)
    end
  end

  describe '.supports_vision?' do
    it 'returns true for all Claude models' do
      expect(described_class.supports_vision?('anthropic.claude-3-haiku-20240307-v1:0')).to be true
      expect(described_class.supports_vision?('anthropic.claude-opus-4-5-20251101-v1:0')).to be true
    end

    it 'returns true for most Nova models except Micro' do
      expect(described_class.supports_vision?('amazon.nova-lite-v1:0')).to be true
      expect(described_class.supports_vision?('amazon.nova-pro-v1:0')).to be true
      expect(described_class.supports_vision?('amazon.nova-micro-v1:0')).to be false
    end

    it 'returns true for Llama 4 models' do
      expect(described_class.supports_vision?('meta.llama4-maverick-70b-instruct-v1:0')).to be true
      expect(described_class.supports_vision?('meta.llama4-scout-17b-instruct-v1:0')).to be true
    end

    it 'returns false for text-only models' do
      expect(described_class.supports_vision?('openai.gpt-oss-120b-20250130-v1:0')).to be false
      expect(described_class.supports_vision?('deepseek.r1-v1:0')).to be false
      expect(described_class.supports_vision?('minimax.minimax-m2')).to be false
    end

    it 'returns true only for Qwen VL variant' do
      expect(described_class.supports_vision?('qwen.qwen3-coder-480b-a22b')).to be false
      expect(described_class.supports_vision?('qwen.qwen3-vl-235b-a22b')).to be true
      expect(described_class.supports_vision?('qwen.qwen3-next-80b-a22b')).to be false
    end

    it 'returns false for unknown models' do
      expect(described_class.supports_vision?('unknown.model')).to be false
    end
  end

  describe '.supports_functions?' do
    it 'returns true for all Claude models' do
      expect(described_class.supports_functions?('anthropic.claude-3-haiku-20240307-v1:0')).to be true
      expect(described_class.supports_functions?('anthropic.claude-opus-4-5-20251101-v1:0')).to be true
    end

    it 'returns appropriate values for Nova models' do
      expect(described_class.supports_functions?('amazon.nova-2-lite-v1:0')).to be true
      expect(described_class.supports_functions?('amazon.nova-premier-v1:0')).to be true
      expect(described_class.supports_functions?('amazon.nova-pro-v1:0')).to be true
      expect(described_class.supports_functions?('amazon.nova-lite-v1:0')).to be false
      expect(described_class.supports_functions?('amazon.nova-micro-v1:0')).to be false
    end

    it 'returns appropriate values for Llama 4 models' do
      expect(described_class.supports_functions?('meta.llama4-maverick-70b-instruct-v1:0')).to be true
      expect(described_class.supports_functions?('meta.llama4-scout-17b-instruct-v1:0')).to be false
    end

    it 'returns true for most modern models' do
      expect(described_class.supports_functions?('qwen.qwen3-coder-480b-a22b')).to be true
      expect(described_class.supports_functions?('deepseek.r1-v1:0')).to be true
      expect(described_class.supports_functions?('google.gemma-3-27b-it')).to be true
    end

    it 'returns false for unknown models' do
      expect(described_class.supports_functions?('unknown.model')).to be false
    end
  end

  describe '.supports_chat?' do
    it 'returns true for all models' do
      expect(described_class.supports_chat?('anthropic.claude-3-haiku-20240307-v1:0')).to be true
      expect(described_class.supports_chat?('amazon.nova-micro-v1:0')).to be true
      expect(described_class.supports_chat?('unknown.model')).to be true
    end
  end

  describe '.supports_streaming?' do
    it 'returns true for all models' do
      expect(described_class.supports_streaming?('anthropic.claude-3-haiku-20240307-v1:0')).to be true
      expect(described_class.supports_streaming?('amazon.nova-micro-v1:0')).to be true
      expect(described_class.supports_streaming?('unknown.model')).to be true
    end
  end

  describe '.supports_json_mode?' do
    it 'returns true for all models' do
      expect(described_class.supports_json_mode?('anthropic.claude-3-haiku-20240307-v1:0')).to be true
      expect(described_class.supports_json_mode?('amazon.nova-micro-v1:0')).to be true
      expect(described_class.supports_json_mode?('unknown.model')).to be true
    end
  end

  describe '.supports_audio?' do
    it 'returns false for all models' do
      expect(described_class.supports_audio?('anthropic.claude-3-haiku-20240307-v1:0')).to be false
      expect(described_class.supports_audio?('amazon.nova-micro-v1:0')).to be false
      expect(described_class.supports_audio?('unknown.model')).to be false
    end
  end

  describe '.supports_structured_output?' do
    it 'returns true for all models' do
      expect(described_class.supports_structured_output?('anthropic.claude-3-haiku-20240307-v1:0')).to be true
      expect(described_class.supports_structured_output?('amazon.nova-micro-v1:0')).to be true
      expect(described_class.supports_structured_output?('unknown.model')).to be true
    end
  end

  describe '.input_price_for' do
    it 'returns correct pricing for Claude models' do
      expect(described_class.input_price_for('anthropic.claude-3-haiku-20240307-v1:0')).to eq(0.25)
      expect(described_class.input_price_for('anthropic.claude-3-5-sonnet-20240620-v1:0')).to eq(3.0)
      expect(described_class.input_price_for('anthropic.claude-opus-4-1-20250805-v1:0')).to eq(15.0)
    end

    it 'returns correct pricing for Nova models' do
      expect(described_class.input_price_for('amazon.nova-micro-v1:0')).to eq(0.035)
      expect(described_class.input_price_for('amazon.nova-premier-v1:0')).to eq(2.5)
    end

    it 'returns default pricing for unknown models' do
      expect(described_class.input_price_for('unknown.model')).to eq(0.1)
    end
  end

  describe '.output_price_for' do
    it 'returns correct pricing for Claude models' do
      expect(described_class.output_price_for('anthropic.claude-3-haiku-20240307-v1:0')).to eq(1.25)
      expect(described_class.output_price_for('anthropic.claude-3-5-sonnet-20240620-v1:0')).to eq(15.0)
      expect(described_class.output_price_for('anthropic.claude-opus-4-1-20250805-v1:0')).to eq(75.0)
    end

    it 'returns correct pricing for Nova models' do
      expect(described_class.output_price_for('amazon.nova-micro-v1:0')).to eq(0.14)
      expect(described_class.output_price_for('amazon.nova-premier-v1:0')).to eq(12.5)
    end

    it 'returns default pricing for unknown models' do
      expect(described_class.output_price_for('unknown.model')).to eq(0.2)
    end
  end

  describe '.format_display_name' do
    it 'humanizes model IDs' do
      expect(described_class.format_display_name('anthropic.claude-3-haiku-20240307-v1:0')).to eq('Claude 3 Haiku 20240307 V1:0')
      expect(described_class.format_display_name('us.amazon.nova-micro-v1:0')).to eq('Nova Micro V1:0')
    end

    it 'handles simple model IDs' do
      expect(described_class.format_display_name('test-model')).to eq('Test Model')
    end
  end

  describe '.model_type' do
    it 'returns chat for all models' do
      expect(described_class.model_type('anthropic.claude-3-haiku-20240307-v1:0')).to eq('chat')
      expect(described_class.model_type('unknown.model')).to eq('chat')
    end
  end

  describe '.modalities_for' do
    it 'returns text modalities for text-only models' do
      modalities = described_class.modalities_for('amazon.nova-micro-v1:0')
      expect(modalities[:input]).to eq(['text'])
      expect(modalities[:output]).to eq(['text'])
    end

    it 'includes image and pdf for vision models' do
      modalities = described_class.modalities_for('anthropic.claude-3-haiku-20240307-v1:0')
      expect(modalities[:input]).to include('text', 'image', 'pdf')
      expect(modalities[:output]).to eq(['text'])
    end
  end

  describe '.capabilities_for' do
    it 'includes streaming for all models' do
      capabilities = described_class.capabilities_for('anthropic.claude-3-haiku-20240307-v1:0')
      expect(capabilities).to include('streaming')
    end

    it 'includes function_calling for supporting models' do
      capabilities = described_class.capabilities_for('anthropic.claude-3-5-sonnet-20240620-v1:0')
      expect(capabilities).to include('function_calling')
    end

    it 'includes reasoning for Claude models' do
      capabilities = described_class.capabilities_for('anthropic.claude-3-haiku-20240307-v1:0')
      expect(capabilities).to include('reasoning')
    end

    it 'includes batch and citations for Claude 3.5+' do
      capabilities = described_class.capabilities_for('anthropic.claude-3-5-sonnet-20240620-v1:0')
      expect(capabilities).to include('batch', 'citations')
    end

    it 'includes batch and citations for Claude 3.7' do
      capabilities = described_class.capabilities_for('anthropic.claude-3-7-sonnet-20250219-v1:0')
      expect(capabilities).to include('batch', 'citations')
    end

    it 'includes batch and citations for Claude 4+' do
      capabilities = described_class.capabilities_for('anthropic.claude-opus-4-20250805-v1:0')
      expect(capabilities).to include('batch', 'citations')
    end

    it 'includes batch and citations for Claude 4.5+' do
      capabilities = described_class.capabilities_for('anthropic.claude-sonnet-4-5-20251101-v1:0')
      expect(capabilities).to include('batch', 'citations')
    end

    it 'does not include batch/citations for Claude 3.0' do
      capabilities = described_class.capabilities_for('anthropic.claude-3-haiku-20240307-v1:0')
      expect(capabilities).not_to include('batch', 'citations')
    end
  end

  describe '.pricing_for' do
    it 'returns structured pricing information' do
      pricing = described_class.pricing_for('anthropic.claude-3-5-sonnet-20240620-v1:0')

      expect(pricing[:text_tokens][:standard][:input_per_million]).to eq(3.0)
      expect(pricing[:text_tokens][:standard][:output_per_million]).to eq(15.0)
      expect(pricing[:text_tokens][:batch][:input_per_million]).to eq(1.5) # 50% discount
      expect(pricing[:text_tokens][:batch][:output_per_million]).to eq(7.5) # 50% discount
    end

    it 'applies 50% discount for batch pricing' do
      pricing = described_class.pricing_for('anthropic.claude-opus-4-1-20250805-v1:0')

      expect(pricing[:text_tokens][:batch][:input_per_million]).to eq(7.5) # 15.0 * 0.5
      expect(pricing[:text_tokens][:batch][:output_per_million]).to eq(37.5) # 75.0 * 0.5
    end

    it 'uses default pricing for unknown models' do
      pricing = described_class.pricing_for('unknown.model')

      expect(pricing[:text_tokens][:standard][:input_per_million]).to eq(0.1)
      expect(pricing[:text_tokens][:standard][:output_per_million]).to eq(0.2)
    end
  end
end
