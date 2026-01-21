# frozen_string_literal: true

module RubyLLM
  module Providers
    class BedrockConverse
      module Streaming
        # Module for handling content extraction from AWS Bedrock Converse streaming responses.
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
            # Tool use starts in 'start' block, then deltas come in 'delta' block
            tool_use_start = data.dig('start', 'toolUse')
            tool_use_delta = data.dig('delta', 'toolUse')


            return nil unless tool_use_start || tool_use_delta

            if tool_use_start
              # Initial tool use block with metadata
              tool_calls = {
                tool_use_start['toolUseId'] => ToolCall.new(
                  id: tool_use_start['toolUseId'],
                  name: tool_use_start['name'],
                  arguments: +''
                )
              }
              tool_calls
            elsif tool_use_delta
              # Delta with input arguments (no id/name in delta)
              tool_calls = {
                nil => ToolCall.new(
                  id: nil,
                  name: nil,
                  arguments: tool_use_delta['input'] || ''
                )
              }
              tool_calls
            end
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
