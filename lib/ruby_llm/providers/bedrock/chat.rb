# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Chat methods for the AWS Bedrock API implementation
      module Chat
        module_function

        def sync_response(connection, payload, additional_headers = {})
          signature = sign_request("#{connection.connection.url_prefix}#{completion_url}", payload:)
          response = connection.post completion_url, payload do |req|
            req.headers.merge! build_headers(signature.headers, streaming: block_given?)
            req.headers = additional_headers.merge(req.headers) unless additional_headers.empty?
          end
          parse_converse_response response
        end

        def format_message(msg)
          if msg.tool_call?
            format_converse_tool_call(msg)
          elsif msg.tool_result?
            format_converse_tool_result(msg)
          else
            format_basic_message(msg)
          end
        end

        def format_basic_message(msg)
          content_parts = Media.format_content(msg.content)

          # Convert content to Converse API format
          converse_content = content_parts.map do |part|
            if part[:type] == 'text' || part[:text]
              { text: part[:text] || part[:content] }
            elsif part[:type] == 'image'
              {
                image: {
                  format: extract_image_format(part[:source][:media_type]),
                  source: {
                    bytes: part[:source][:data]
                  }
                }
              }
            elsif part[:type] == 'document'
              {
                document: {
                  format: extract_document_format(part[:source][:media_type]),
                  name: part[:name] || 'document',
                  source: {
                    bytes: part[:source][:data]
                  }
                }
              }
            else
              part
            end
          end

          {
            role: convert_converse_role(msg.role),
            content: converse_content
          }
        end

        def format_converse_tool_call(msg)
          return { role: 'assistant', content: msg.content.value } if msg.content.is_a?(RubyLLM::Content::Raw)

          content = []

          # Add text content if present
          unless msg.content.nil? || msg.content.empty?
            content << { text: msg.content.to_s }
          end

          # Add tool uses
          msg.tool_calls.each_value do |tool_call|
            content << {
              toolUse: {
                toolUseId: tool_call.id,
                name: tool_call.name,
                input: tool_call.arguments
              }
            }
          end

          {
            role: 'assistant',
            content: content
          }
        end

        def format_converse_tool_result(msg)
          content = if msg.content.is_a?(RubyLLM::Content::Raw)
                      msg.content.value
                    else
                      [{
                        toolResult: {
                          toolUseId: msg.tool_call_id,
                          content: Media.format_content(msg.content).map { |c|
                            c[:type] == 'text' || c[:text] ? { text: c[:text] || c[:content] } : c
                          }
                        }
                      }]
                    end

          {
            role: 'user',
            content: content
          }
        end

        def convert_converse_role(role)
          case role
          when :tool, :user then 'user'
          else 'assistant'
          end
        end

        def extract_image_format(media_type)
          case media_type
          when 'image/jpeg' then 'jpeg'
          when 'image/png' then 'png'
          when 'image/gif' then 'gif'
          when 'image/webp' then 'webp'
          else 'png'
          end
        end

        def extract_document_format(media_type)
          case media_type
          when 'application/pdf' then 'pdf'
          when 'text/csv' then 'csv'
          when 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' then 'doc'
          when 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' then 'xls'
          when 'text/html' then 'html'
          when 'text/plain' then 'txt'
          when 'text/markdown' then 'md'
          else 'pdf'
          end
        end

        private

        def completion_url
          "model/#{@model_id}/converse"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil) # rubocop:disable Lint/UnusedMethodArgument,Metrics/ParameterLists
          @model_id = model.id

          system_messages, chat_messages = Anthropic::Chat.separate_messages(messages)
          system_content = build_converse_system_content(system_messages)

          build_base_payload(chat_messages, model).tap do |payload|
            add_converse_optional_fields(payload, system_content:, tools:, temperature:, model:)
          end
        end

        def build_base_payload(chat_messages, model)
          # Filter out messages with no content and no tool calls (can happen with streaming)
          valid_messages = chat_messages.reject do |msg|
            msg.role == :assistant && msg.content.nil? && (msg.tool_calls.nil? || msg.tool_calls.empty?)
          end

          {
            messages: combine_tool_results(valid_messages).map { |msg| format_message(msg) }
          }
        end

        # Combines consecutive tool result messages into a single message
        # This is required by Bedrock's Converse API when handling parallel tool calls
        def combine_tool_results(messages)
          combined = []
          tool_results_buffer = []

          messages.each do |msg|
            if msg.tool_result?
              tool_results_buffer << msg
            else
              # Flush accumulated tool results as a single combined message
              unless tool_results_buffer.empty?
                combined << create_combined_tool_result_message(tool_results_buffer)
                tool_results_buffer = []
              end
              combined << msg
            end
          end

          # Flush any remaining tool results
          unless tool_results_buffer.empty?
            combined << create_combined_tool_result_message(tool_results_buffer)
          end

          combined
        end

        # Creates a single message containing multiple tool results
        def create_combined_tool_result_message(tool_result_messages)
          return tool_result_messages.first if tool_result_messages.length == 1

          # Create a combined message with Raw content containing all tool results
          all_tool_results = tool_result_messages.map do |msg|
            {
              toolResult: {
                toolUseId: msg.tool_call_id,
                content: Media.format_content(msg.content).map { |c|
                  c[:type] == 'text' || c[:text] ? { text: c[:text] || c[:content] } : c
                }
              }
            }
          end

          Message.new(
            role: :tool,
            content: Content::Raw.new(all_tool_results),
            tool_call_id: tool_result_messages.first.tool_call_id # Keep first ID for reference
          )
        end

        def build_converse_system_content(system_messages)
          return nil if system_messages.empty?

          if system_messages.length > 1
            RubyLLM.logger.warn(
              "Bedrock's Converse API only supports a single system message. " \
              'Multiple system messages will be combined into one.'
            )
          end

          system_messages.flat_map do |msg|
            content = msg.content

            if content.is_a?(RubyLLM::Content::Raw)
              [{ text: content.value.to_s }]
            else
              [{ text: Media.format_content(msg.content).map { |c| c[:text] || c.to_s }.join }]
            end
          end
        end

        def add_converse_optional_fields(payload, system_content:, tools:, temperature:, model:)
          # Add inferenceConfig
          inference_config = {}
          inference_config[:maxTokens] = model.max_tokens || 4096
          inference_config[:temperature] = temperature unless temperature.nil?
          payload[:inferenceConfig] = inference_config

          # Add system messages
          payload[:system] = system_content unless system_content.nil? || system_content.empty?

          # Add tools
          if tools.any?
            payload[:toolConfig] = {
              tools: tools.values.map { |t| format_tool_for_converse(t) }
            }
          end
        end

        def format_tool_for_converse(tool)
          input_schema = tool.params_schema ||
                         RubyLLM::Tool::SchemaDefinition.from_parameters(tool.parameters)&.json_schema

          tool_spec = {
            toolSpec: {
              name: tool.name,
              description: tool.description,
              inputSchema: { json: input_schema || Anthropic::Tools.default_input_schema }
            }
          }

          return tool_spec if tool.provider_params.empty?

          RubyLLM::Utils.deep_merge(tool_spec, tool.provider_params)
        end

        def parse_converse_response(response)
          data = response.body
          output = data['output'] || {}
          message = output['message'] || {}
          content_blocks = message['content'] || []

          text_content = extract_converse_text_content(content_blocks)
          tool_use_blocks = extract_converse_tool_uses(content_blocks)

          build_converse_message(data, text_content, tool_use_blocks, response)
        end

        def extract_converse_text_content(blocks)
          text_blocks = blocks.select { |c| c['text'] }
          text_blocks.map { |c| c['text'] }.join
        end

        def extract_converse_tool_uses(blocks)
          blocks.select { |c| c['toolUse'] }.map { |c| c['toolUse'] }
        end

        def build_converse_message(data, content, tool_use_blocks, response)
          usage = data['usage'] || {}

          Message.new(
            role: :assistant,
            content: content,
            tool_calls: parse_converse_tool_calls(tool_use_blocks),
            input_tokens: usage['inputTokens'],
            output_tokens: usage['outputTokens'],
            model_id: @model_id,
            raw: response
          )
        end

        def parse_converse_tool_calls(tool_use_blocks)
          return nil if tool_use_blocks.nil? || tool_use_blocks.empty?

          tool_calls = {}
          tool_use_blocks.each do |block|
            tool_calls[block['toolUseId']] = ToolCall.new(
              id: block['toolUseId'],
              name: block['name'],
              arguments: block['input']
            )
          end

          tool_calls
        end
      end
    end
  end
end
