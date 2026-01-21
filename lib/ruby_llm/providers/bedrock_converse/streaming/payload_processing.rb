# frozen_string_literal: true

require 'base64'

module RubyLLM
  module Providers
    class BedrockConverse
      module Streaming
        # Module for processing payloads from AWS Bedrock Converse streaming responses.
        module PayloadProcessing
          def process_payload(payload, &)
            json_payload = extract_json_payload(payload)
            parse_and_process_json(json_payload, &)
          rescue JSON::ParserError => e
            log_json_parse_error(e, json_payload)
          rescue StandardError => e
            log_general_error(e)
          end

          private

          def extract_json_payload(payload)
            json_start = payload.index('{')
            json_end = payload.rindex('}')
            payload[json_start..json_end]
          end

          def parse_and_process_json(json_payload, &)
            json_data = JSON.parse(json_payload)
            process_json_data(json_data, &)
          end

          def process_json_data(json_data, &)
            # Converse Stream API sends JSON directly (no base64 encoding)
            # Old invoke API used base64-encoded bytes
            data = if json_data['bytes']
                     decode_and_parse_data(json_data)
                   else
                     json_data
                   end

            create_and_yield_chunk(data, &)
          end

          def decode_and_parse_data(json_data)
            decoded_bytes = Base64.strict_decode64(json_data['bytes'])
            JSON.parse(decoded_bytes)
          end

          def create_and_yield_chunk(data, &block)
            block.call(build_chunk(data))
          end

          def build_chunk(data)
            Chunk.new(
              **extract_chunk_attributes(data)
            )
          end

          def extract_chunk_attributes(data)
            {
              role: :assistant,
              model_id: extract_model_id(data),
              content: extract_streaming_content(data),
              input_tokens: extract_input_tokens(data),
              output_tokens: extract_output_tokens(data),
              cached_tokens: extract_cached_tokens(data),
              cache_creation_tokens: extract_cache_creation_tokens(data),
              tool_calls: extract_tool_calls(data)
            }
          end

          def log_json_parse_error(error, json_payload)
            RubyLLM.logger.debug "Failed to parse payload as JSON: #{error.message}"
            RubyLLM.logger.debug "Attempted JSON payload: #{json_payload.inspect}"
          end

          def log_general_error(error)
            RubyLLM.logger.debug "Error processing payload: #{error.message}"
          end
        end
      end
    end
  end
end
