# frozen_string_literal: true

require 'json'

module RubyLLM
  module Providers
    class Bedrock
      # Models methods for the AWS Bedrock API implementation
      module Models
        def list_models
          mgmt_api_base = "https://bedrock.#{@config.bedrock_region}.amazonaws.com"
          full_models_url = "#{mgmt_api_base}/#{models_url}"
          signature = sign_request(full_models_url, method: :get)
          response = @connection.get(full_models_url) do |req|
            req.headers.merge! signature.headers
          end

          parse_list_models_response(response, slug, capabilities)
        end

        module_function

        def models_url
          'foundation-models'
        end

        def load_bedrock_model_ids
          aliases_path = File.expand_path('../../aliases.json', __dir__)
          aliases = JSON.parse(File.read(aliases_path))

          # Extract all unique model IDs that have a bedrock provider
          bedrock_ids = aliases.values
            .select { |providers| providers.is_a?(Hash) && providers.key?('bedrock') }
            .map { |providers| providers['bedrock'] }
            .compact
            .uniq

          # Extract base model patterns for matching
          # E.g., "us.amazon.nova-lite-v1:0" -> ["amazon", "nova"]
          #       "anthropic.claude-3-5-haiku-20241022-v1:0" -> ["anthropic", "claude"]
          #       "deepseek.v3-v1:0" -> ["deepseek"]
          patterns = bedrock_ids.flat_map do |model_id|
            # Remove region prefixes (us., eu., ap., global.)
            clean_id = model_id.sub(/^(us|eu|ap|global)\./, '')

            # Split on dots and take vendor parts
            parts = clean_id.split('.')
            vendor_part = parts.first || clean_id

            # Extract key terms (vendor name, model family)
            vendor_part.split(/[-_]/).first(2)
          end.compact.uniq

          patterns
        end

        def parse_list_models_response(response, slug, capabilities)
          models = Array(response.body['modelSummaries'])
          bedrock_model_ids = load_bedrock_model_ids

          models.select { |m| bedrock_model_ids.any? { |id| m['modelId'].include?(id) } }.map do |model_data|
            model_id = model_data['modelId']
            final_model_id = model_id_with_region(model_id, model_data)

            Model::Info.new(
              id: final_model_id,
              name: model_data['modelName'] || capabilities.format_display_name(model_id),
              provider: slug,
              family: capabilities.model_family(final_model_id),
              created_at: nil,
              context_window: extract_context_window(model_data),
              max_output_tokens: extract_max_output_tokens(model_data),
              modalities: extract_modalities(model_data),
              capabilities: extract_capabilities(model_data),
              pricing: capabilities.pricing_for(final_model_id),
              metadata: {
                provider_name: model_data['providerName'],
                inference_types: model_data['inferenceTypesSupported'] || [],
                streaming_supported: model_data['responseStreamingSupported'] || false,
                input_modalities: model_data['inputModalities'] || [],
                output_modalities: model_data['outputModalities'] || []
              }
            )
          end
        end

        def extract_context_window(model_data)
          model_id = model_data['modelId']

          case model_id
          when /claude-3-opus/, /claude-3-sonnet/, /claude-3-haiku/ then 200_000
          when /claude-3-5/, /claude-3-7/ then 200_000
          when /claude-sonnet-4/, /claude-opus-4/, /claude-haiku-4/ then 200_000
          when /nova/ then 300_000
          when /llama-3/ then 128_000
          when /deepseek/ then 64_000
          when /qwen/ then 32_000
          when /mistral/, /pixtral/ then 128_000
          when /gpt-oss/ then 128_000
          else 128_000
          end
        end

        def extract_max_output_tokens(model_data)
          model_id = model_data['modelId']

          case model_id
          when /claude/ then 4_096
          when /nova/ then 5_000
          when /llama/ then 4_096
          when /deepseek/ then 8_192
          when /qwen/ then 8_192
          when /mistral/, /pixtral/ then 8_192
          when /gpt-oss/ then 4_096
          else 4_096
          end
        end

        def extract_modalities(model_data)
          input_modalities = (model_data['inputModalities'] || ['TEXT']).map(&:downcase)
          output_modalities = (model_data['outputModalities'] || ['TEXT']).map(&:downcase)

          {
            input: input_modalities,
            output: output_modalities
          }
        end

        def extract_capabilities(model_data)
          capabilities = []

          capabilities << 'streaming' if model_data['responseStreamingSupported']

          model_id = model_data['modelId']

          # Add function calling for models that support it
          capabilities << 'function_calling' if model_id.match?(/claude|nova|llama-3|qwen/)

          # Add vision capability if images are supported
          capabilities << 'vision' if (model_data['inputModalities'] || []).include?('IMAGE')

          # Add audio capability if audio is supported
          capabilities << 'audio' if (model_data['inputModalities'] || []).include?('AUDIO')

          # Add video capability if video is supported
          capabilities << 'video' if (model_data['inputModalities'] || []).include?('VIDEO')

          capabilities
        end

        def create_model_info(model_data, slug, _capabilities)
          model_id = model_data['modelId']

          Model::Info.new(
            id: model_id_with_region(model_id, model_data),
            name: model_data['modelName'] || model_id,
            provider: slug,
            family: 'claude',
            created_at: nil,
            context_window: 200_000,
            max_output_tokens: 4096,
            modalities: { input: ['text'], output: ['text'] },
            capabilities: [],
            pricing: {},
            metadata: {}
          )
        end

        def model_id_with_region(model_id, model_data)
          return model_id unless model_data['inferenceTypesSupported']&.include?('INFERENCE_PROFILE')
          return model_id if model_data['inferenceTypesSupported']&.include?('ON_DEMAND')

          desired_region_prefix = inference_profile_region_prefix

          # Return unchanged if model already has the correct region prefix
          return model_id if model_id.start_with?("#{desired_region_prefix}.")

          # Remove any existing region prefix (e.g., "us.", "eu.", "ap.")
          clean_model_id = model_id.sub(/^[a-z]{2}\./, '')

          # Apply the desired region prefix
          "#{desired_region_prefix}.#{clean_model_id}"
        end

        def inference_profile_region_prefix
          # Extract region prefix from bedrock_region (e.g., "eu-west-3" -> "eu")
          region = @config.bedrock_region.to_s
          return 'us' if region.empty? # Default fallback

          # Take first two characters as the region prefix
          region[0, 2]
        end
      end
    end
  end
end
