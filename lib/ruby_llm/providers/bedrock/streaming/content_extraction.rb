# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Streaming
        # Module for handling content extraction from AWS Bedrock streaming responses.
        module ContentExtraction
          def json_delta?(data)
            # Converse Stream format for tool input delta
            data['delta'] && data.dig('delta', 'toolUse')
          end

          def extract_streaming_content(data)
            return '' unless data.is_a?(Hash)

            # Converse Stream format: text is in delta.text
            return data.dig('delta', 'text').to_s if data['delta'] && data['delta']['text']

            ''
          end

          def extract_tool_calls(data)
            # Extract tool calls from Converse Stream format
            return nil unless data['delta']

            tool_use = data.dig('delta', 'toolUse')
            return nil unless tool_use

            {
              tool_use['toolUseId'] => ToolCall.new(
                id: tool_use['toolUseId'],
                name: tool_use['name'],
                arguments: {}
              )
            }
          end

          def extract_model_id(data)
            @model_id
          end

          def extract_input_tokens(data)
            data.dig('usage', 'inputTokens')
          end

          def extract_output_tokens(data)
            data.dig('usage', 'outputTokens')
          end

          def extract_cached_tokens(data)
            # Converse API doesn't expose cache metrics in the same way
            nil
          end

          def extract_cache_creation_tokens(data)
            # Converse API doesn't expose cache metrics in the same way
            nil
          end
        end
      end
    end
  end
end
