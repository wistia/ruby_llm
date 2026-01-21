# frozen_string_literal: true

require 'json'

module RubyLLM
  module Providers
    class BedrockConverse
      # Models methods for the AWS Bedrock Converse API implementation
      module Models
        def list_models
          mgmt_api_base = "https://bedrock.#{@config.bedrock_region}.amazonaws.com"
          full_models_url = "#{mgmt_api_base}/#{models_url}"
          signature = sign_request(full_models_url, method: :get)

          # Create a direct connection for the models API (different base URL than runtime API)
          models_connection = Faraday.new(mgmt_api_base) do |faraday|
            faraday.request :json
            faraday.response :json
            faraday.use :llm_errors, provider: self
            faraday.adapter :net_http
          end

          response = models_connection.get(models_url) do |req|
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

          # Extract all unique model IDs that have a bedrock or bedrock_converse provider
          bedrock_ids = aliases.values
            .select { |providers| providers.is_a?(Hash) && (providers.key?('bedrock') || providers.key?('bedrock_converse')) }
            .flat_map { |providers| [providers['bedrock'], providers['bedrock_converse']] }
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
              context_window: capabilities.context_window_for(final_model_id),
              max_output_tokens: capabilities.max_tokens_for(final_model_id),
              modalities: capabilities.modalities_for(final_model_id),
              capabilities: capabilities.capabilities_for(final_model_id),
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

        def create_model_info(model_data, slug, capabilities)
          model_id = model_data['modelId']
          final_model_id = model_id_with_region(model_id, model_data)

          Model::Info.new(
            id: final_model_id,
            name: model_data['modelName'] || capabilities.format_display_name(model_id),
            provider: slug,
            family: capabilities.model_family(final_model_id),
            created_at: nil,
            context_window: capabilities.context_window_for(final_model_id),
            max_output_tokens: capabilities.max_tokens_for(final_model_id),
            modalities: capabilities.modalities_for(final_model_id),
            capabilities: capabilities.capabilities_for(final_model_id),
            pricing: capabilities.pricing_for(final_model_id),
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
