# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Determines capabilities and pricing for AWS Bedrock models
      module Capabilities
        module_function

        def context_window_for(model_id)
          family = model_family(model_id)
          CONTEXT_WINDOW.fetch(family, 128_000)
        end

        def max_tokens_for(model_id)
          family = model_family(model_id)
          MAX_TOKENS.fetch(family, 4_096)
        end

        def input_price_for(model_id)
          PRICES.dig(model_family(model_id), :input) || default_input_price
        end

        def output_price_for(model_id)
          PRICES.dig(model_family(model_id), :output) || default_output_price
        end

        def supports_chat?(model_id)
          true
        end

        def supports_streaming?(model_id)
          true
        end

        def supports_images?(model_id)
          family = model_family(model_id)
          SUPPORTS_IMAGES[family] || false
        end

        def supports_vision?(model_id)
          supports_images?(model_id)
        end

        def supports_functions?(model_id)
          family = model_family(model_id)
          SUPPORTS_FUNCTIONS.fetch(family, false)
        end

        def supports_audio?(_model_id)
          false
        end

        def supports_json_mode?(model_id)
          true
        end

        def format_display_name(model_id)
          model_id.then { |id| humanize(id) }
        end

        def model_type(_model_id)
          'chat'
        end

        def supports_structured_output?(_model_id)
          true
        end

        SUPPORTS_FUNCTIONS = {
          # Claude models - all support tool-calling
          claude3_haiku: true,
          claude3_5_haiku: true,
          claude3_5_sonnet: true,
          claude3_7_sonnet: true,
          claude4_sonnet: true,
          claude4_opus: true,
          claude4_1_opus: true,
          claude4_5_sonnet: true,
          claude4_5_opus: true,
          claude4_5_haiku: true,
          # Nova models
          nova_2_lite: true,
          nova_premier: true,
          nova_pro: true,
          nova_lite: false,
          nova_micro: false,
          # OpenAI models
          gpt_oss_120b: true,
          gpt_oss_20b: true,
          # Llama4
          llama4_maverick: true,
          llama4_scout: false,
          # Qwen Models
          qwen3_coder_480b: true,
          qwen3_vl_235b: true,
          qwen3_next_80b: true,
          # Minimax
          minimax_m2: true,
          # DeepSeek
          deepseek_r1: true,
          deepseek_v3: true,
          # Google Gemma
          gemma3_27b: true,
          gemma3_12b: true,
          gemma3_4b: true,
          # Kimi
          kimi_k2_thinking: true,
          # Mistral
          mistral_large_3: true,
          pixtral_large_2502: true
        }.freeze

        MAX_TOKENS = {
          # Claude models
          claude3_haiku: 4_096,
          claude3_5_haiku: 8_192,
          claude3_5_sonnet: 8_192,
          claude3_7_sonnet: 64_000,
          claude4_sonnet: 64_000,
          claude4_opus: 32_000,
          claude4_1_opus: 32_000,
          claude4_5_sonnet: 64_000,
          claude4_5_opus: 64_000,
          claude4_5_haiku: 64_000,
          # Nova models
          nova_2_lite: 10_000,
          nova_premier: 10_000,
          nova_pro: 10_000,
          nova_lite: 10_000,
          nova_micro: 10_000,
          # Llama 4 models
          llama4_maverick: 8192,
          llama4_scout: 8192,
          # OpenAI models
          gpt_oss_120b: 8192,
          gpt_oss_20b: 8192,
          # Qwen models
          qwen3_coder_480b: 32_768,
          qwen3_vl_235b: 256_000,
          qwen3_next_80b: 32_000,
          # Minimax
          minimax_m2: 128_000,
          # DeepSeek
          deepseek_r1: 8_192,
          deepseek_v3: 8_192,
          # Gemma
          gemma3_27b: 128_000,
          gemma3_12b: 128_000,
          gemma3_4b: 128_000,
          # Kimi
          kimi_k2_thinking: 16_400,
          # Mistral
          mistral_large_3: 32_768,
          pixtral_large_2502: 4_096,
        }.freeze

        CONTEXT_WINDOW = {
          # Claude models
          claude3_haiku: 200_000,
          claude3_5_haiku: 200_000,
          claude3_5_sonnet: 200_000,
          claude3_7_sonnet: 200_000,
          claude4_sonnet: 200_000,
          claude4_opus: 200_000,
          claude4_1_opus: 200_000,
          claude4_5_sonnet: 200_000,
          claude4_5_opus: 200_000,
          claude4_5_haiku: 200_000,
          # Nova models
          nova_2_lite: 1_000_000,
          nova_premier: 1_000_000,
          nova_pro: 300_000,
          nova_lite: 300_000,
          nova_micro: 128_000,
          # Llama 4 models
          llama4_maverick: 1_000_000,
          llama4_scout: 3_500_000,
          # OpenAI models
          gpt_oss_120b: 128_000,
          gpt_oss_20b: 128_000,
          # Qwen models
          qwen3_coder_480b: 131_072,
          qwen3_vl_235b: 256_000,
          qwen3_next_80b: 256_000,
          # Minimax
          minimax_m2: 400_000,
          # DeepSeek
          deepseek_r1: 128_000,
          deepseek_v3: 163_840,
          # Gemma
          gemma3_27b: 128_000,
          gemma3_12b: 128_000,
          gemma3_4b: 128_000,
          # Kimi
          kimi_k2_thinking: 256_000,
          # Mistral
          mistral_large_3: 256_000,
          pixtral_large_2502: 128_000,
        }.freeze

        # Image support by model family
        SUPPORTS_IMAGES = {
          # Claude models - all support images
          claude3_haiku: true,
          claude3_5_haiku: true,
          claude3_5_sonnet: true,
          claude3_7_sonnet: true,
          claude4_sonnet: true,
          claude4_opus: true,
          claude4_1_opus: true,
          claude4_5_sonnet: true,
          claude4_5_opus: true,
          claude4_5_haiku: true,
          # Nova models - all except micro
          nova_2_lite: true,
          nova_premier: true,
          nova_pro: true,
          nova_lite: true,
          nova_micro: false,
          # Llama 4 models - all support images
          llama4_maverick: true,
          llama4_scout: true,
          # OpenAI models - do not support images
          gpt_oss_120b: false,
          gpt_oss_20b: false,
          # Qwen models - only VL variant
          qwen3_coder_480b: false,
          qwen3_vl_235b: true,
          qwen3_next_80b: false,
          # Minimax - does not support images
          minimax_m2: false,
          # DeepSeek - do not support images
          deepseek_r1: false,
          deepseek_v3: false,
          # Gemma - all support images
          gemma3_27b: true,
          gemma3_12b: true,
          gemma3_4b: true,
          # Kimi - does not support images
          kimi_k2_thinking: false,
          # Mistral
          mistral_large_3: false,
          pixtral_large_2502: true,
        }.freeze

        # Model family patterns for capability lookup
        # Patterns should match AWS Bedrock model ID format closely
        # IMPORTANT: More specific patterns must come BEFORE less specific ones!
        MODEL_FAMILIES = {
          # Claude 3.x models (most specific first)
          /\.claude-3-7-sonnet-/ => :claude3_7_sonnet,
          /\.claude-3-5-sonnet-/ => :claude3_5_sonnet,
          /\.claude-3-5-haiku-/ => :claude3_5_haiku,
          /\.claude-3-haiku-/ => :claude3_haiku,
          # Claude 4.5 models (must come before Claude 4.x patterns)
          /\.claude-sonnet-4-5-/ => :claude4_5_sonnet,
          /\.claude-opus-4-5-/ => :claude4_5_opus,
          /\.claude-haiku-4-5-/ => :claude4_5_haiku,
          # Claude 4.1 models (must come before Claude 4.x patterns)
          /\.claude-opus-4-1-/ => :claude4_1_opus,
          # Claude 4 models (more general patterns last)
          /\.claude-sonnet-4-/ => :claude4_sonnet,
          /\.claude-opus-4-/ => :claude4_opus,
          # Amazon Nova models (specific variants first, match vendor prefix)
          /\.nova-2-lite/ => :nova_2_lite,
          /\.nova-premier/ => :nova_premier,
          /\.nova-pro/ => :nova_pro,
          /\.nova-lite/ => :nova_lite,
          /\.nova-micro/ => :nova_micro,
          # Meta Llama models
          /\.llama4-maverick-/ => :llama4_maverick,
          /\.llama4-scout-/ => :llama4_scout,
          # OpenAI models
          /\.gpt-oss-120b-/ => :gpt_oss_120b,
          /\.gpt-oss-20b-/ => :gpt_oss_20b,
          # Qwen models
          /\.qwen3-coder-480b-/ => :qwen3_coder_480b,
          /\.qwen3-vl-235b-/ => :qwen3_vl_235b,
          /\.qwen3-next-80b-/ => :qwen3_next_80b,
          # Minimax models
          /\.minimax-m2/ => :minimax_m2,
          # DeepSeek models
          /deepseek\.r1/ => :deepseek_r1,
          /deepseek\.v3/ => :deepseek_v3,
          # Google Gemma models
          /\.gemma-3-27b-/ => :gemma3_27b,
          /\.gemma-3-12b-/ => :gemma3_12b,
          /\.gemma-3-4b-/ => :gemma3_4b,
          # Kimi models
          /\.kimi-k2-thinking/ => :kimi_k2_thinking,
          # Mistral models (specific variants)
          /\.mistral-large-3-/ => :mistral_large_3,
          /\.pixtral-large-2502-/ => :pixtral_large_2502,
        }.freeze

        def model_family(model_id)
          MODEL_FAMILIES.find { |pattern, _family| model_id.match?(pattern) }&.last || :other
        end

        # Pricing information for Bedrock models (per million tokens)
        PRICES = {
          # Claude models
          claude3_haiku: { input: 0.25, output: 1.25 },
          claude3_5_haiku: { input: 1.0, output: 5.0 },
          claude3_5_sonnet: { input: 3.0, output: 15.0 },
          claude3_7_sonnet: { input: 3.0, output: 15.0 },
          claude4_sonnet: { input: 3.0, output: 15.0 },
          claude4_opus: { input: 15.0, output: 75.0 },
          claude4_1_opus: { input: 15.0, output: 75.0 },
          claude4_5_sonnet: { input: 3.0, output: 15.0 },
          claude4_5_opus: { input: 5.0, output: 25.0 },
          claude4_5_haiku: { input: 1.1, output: 5.5 },
          # Amazon Nova models
          nova_2_lite: { input: 0.33, output: 2.75 },
          nova_micro: { input: 0.035, output: 0.14 },
          nova_lite: { input: 0.06, output: 0.24 },
          nova_pro: { input: 0.8, output: 3.2 },
          nova_premier: { input: 2.5, output: 12.5 },
          # Meta Llama models
          llama4_maverick: { input: 0.24, output: 0.97 },
          llama4_scout: { input: 0.17, output: 0.66 },
          # OpenAI models
          gpt_oss_120b: { input: 0.15, output: 0.6 },
          gpt_oss_20b: { input: 0.07, output: 0.3 },
          # Qwen models
          qwen3_coder_480b: { input: 0.45, output: 1.8 },
          qwen3_vl_235b: { input: 0.53, output: 2.66 },
          qwen3_next_80b: { input: 0.15, output: 1.2 },
          # Minimax models
          minimax_m2: { input: 0.30, output: 1.20 },
          # DeepSeek models
          deepseek_r1: { input: 1.35, output: 5.4 },
          deepseek_v3: { input: 0.58, output: 1.68 },
          # Google Gemma models
          gemma3_27b: { input: 0.23, output: 0.38 },
          gemma3_12b: { input: 0.09, output: 0.29 },
          gemma3_4b: { input: 0.04, output: 0.08 },
          # Kimi models
          kimi_k2_thinking: { input: 0.60, output: 2.50 },
          # Mistral models
          mistral_large_3: { input: 0.50, output: 1.50 },
          pixtral_large_2502: { input: 2.0, output: 6.0 },
        }.freeze

        def default_input_price
          0.1
        end

        def default_output_price
          0.2
        end

        def humanize(id)
          id.tr('-', ' ')
            .split('.')
            .last
            .split
            .map(&:capitalize)
            .join(' ')
        end

        def modalities_for(model_id)
          modalities = {
            input: ['text'],
            output: ['text']
          }

          if supports_vision?(model_id)
            modalities[:input] << 'image'
            modalities[:input] << 'pdf'
          end

          modalities
        end

        def capabilities_for(model_id)
          capabilities = []

          capabilities << 'streaming' if supports_streaming?(model_id)

          capabilities << 'function_calling' if supports_functions?(model_id)

          capabilities << 'reasoning' if model_id.match?(/claude/)

          # Claude 3.5+, 3.7+, and Claude 4+ support batch and citations
          if model_id.match?(/claude-3-5|claude-3-7|claude-[^3]+-4/)
            capabilities << 'batch'
            capabilities << 'citations'
          end

          capabilities
        end

        def pricing_for(model_id)
          family = model_family(model_id)
          prices = PRICES.fetch(family, { input: default_input_price, output: default_output_price })

          standard_pricing = {
            input_per_million: prices[:input],
            output_per_million: prices[:output]
          }

          batch_pricing = {
            input_per_million: prices[:input] * 0.5,
            output_per_million: prices[:output] * 0.5
          }

          {
            text_tokens: {
              standard: standard_pricing,
              batch: batch_pricing
            }
          }
        end
      end
    end
  end
end
