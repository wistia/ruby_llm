# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::BedrockConverse::Chat do
  # Create a test class that includes the Chat module for testing
  let(:chat_instance) do
    klass = Class.new do
      include RubyLLM::Providers::BedrockConverse::Chat
      attr_accessor :model_id

      def initialize
        @model_id = 'test-model'
      end
    end
    klass.new
  end

  let(:model) { instance_double(RubyLLM::Model::Info, id: 'anthropic.claude-3-5-haiku', max_tokens: 8192) }

  describe '.format_basic_message' do
    it 'formats text-only user messages' do
      message = RubyLLM::Message.new(role: :user, content: 'Hello, world!')

      result = described_class.format_basic_message(message)

      expect(result[:role]).to eq('user')
      expect(result[:content]).to be_an(Array)
      expect(result[:content].first).to eq({ text: 'Hello, world!' })
    end

    it 'formats assistant messages' do
      message = RubyLLM::Message.new(role: :assistant, content: 'Hi there!')

      result = described_class.format_basic_message(message)

      expect(result[:role]).to eq('assistant')
      expect(result[:content].first).to eq({ text: 'Hi there!' })
    end

    it 'formats messages with image attachments' do
      content = RubyLLM::Content.new('What is this?')
      # Add a mock image attachment
      attachment = instance_double(
        RubyLLM::Attachment,
        type: :image,
        mime_type: 'image/jpeg',
        encoded: 'base64encodeddata'
      )
      allow(content).to receive(:attachments).and_return([attachment])
      message = RubyLLM::Message.new(role: :user, content: content)

      result = described_class.format_basic_message(message)

      expect(result[:content].length).to eq(2)
      expect(result[:content].first).to eq({ text: 'What is this?' })
      expect(result[:content].last).to include(
        image: hash_including(
          format: 'jpeg',
          source: { bytes: 'base64encodeddata' }
        )
      )
    end

    it 'formats messages with PDF attachments' do
      content = RubyLLM::Content.new('Analyze this document')
      attachment = instance_double(
        RubyLLM::Attachment,
        type: :pdf,
        mime_type: 'application/pdf',
        encoded: 'pdfbase64data',
        filename: 'document.pdf'
      )
      allow(content).to receive(:attachments).and_return([attachment])
      message = RubyLLM::Message.new(role: :user, content: content)

      result = described_class.format_basic_message(message)

      expect(result[:content].last).to include(
        document: hash_including(
          format: 'pdf',
          name: 'document',
          source: { bytes: 'pdfbase64data' }
        )
      )
    end
  end

  describe '.extract_image_format' do
    it 'extracts jpeg format' do
      expect(described_class.extract_image_format('image/jpeg')).to eq('jpeg')
    end

    it 'extracts png format' do
      expect(described_class.extract_image_format('image/png')).to eq('png')
    end

    it 'extracts gif format' do
      expect(described_class.extract_image_format('image/gif')).to eq('gif')
    end

    it 'extracts webp format' do
      expect(described_class.extract_image_format('image/webp')).to eq('webp')
    end

    it 'defaults to png for unknown formats' do
      expect(described_class.extract_image_format('image/unknown')).to eq('png')
    end
  end

  describe '.extract_document_format' do
    it 'extracts pdf format' do
      expect(described_class.extract_document_format('application/pdf')).to eq('pdf')
    end

    it 'extracts csv format' do
      expect(described_class.extract_document_format('text/csv')).to eq('csv')
    end

    it 'extracts doc format for Word documents' do
      expect(described_class.extract_document_format('application/msword')).to eq('doc')
      expect(described_class.extract_document_format('application/vnd.openxmlformats-officedocument.wordprocessingml.document')).to eq('doc')
    end

    it 'extracts xls format for Excel documents' do
      expect(described_class.extract_document_format('application/vnd.ms-excel')).to eq('xls')
      expect(described_class.extract_document_format('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')).to eq('xls')
    end

    it 'extracts html format' do
      expect(described_class.extract_document_format('text/html')).to eq('html')
    end

    it 'extracts txt format' do
      expect(described_class.extract_document_format('text/plain')).to eq('txt')
    end

    it 'extracts md format' do
      expect(described_class.extract_document_format('text/markdown')).to eq('md')
    end

    it 'defaults to pdf for unknown formats' do
      expect(described_class.extract_document_format('application/unknown')).to eq('pdf')
    end
  end

  describe '.convert_converse_role' do
    it 'converts user role to user' do
      expect(described_class.convert_converse_role(:user)).to eq('user')
    end

    it 'converts tool role to user' do
      expect(described_class.convert_converse_role(:tool)).to eq('user')
    end

    it 'converts assistant role to assistant' do
      expect(described_class.convert_converse_role(:assistant)).to eq('assistant')
    end

    it 'converts system role to assistant' do
      expect(described_class.convert_converse_role(:system)).to eq('assistant')
    end
  end

  describe '.format_converse_tool_call' do
    it 'formats tool call with text content' do
      tool_call = RubyLLM::ToolCall.new(
        id: 'tool_123',
        name: 'get_weather',
        arguments: { location: 'Boston' }
      )
      message = RubyLLM::Message.new(
        role: :assistant,
        content: 'Let me check the weather for you.',
        tool_calls: { 'tool_123' => tool_call }
      )

      result = described_class.format_converse_tool_call(message)

      expect(result[:role]).to eq('assistant')
      expect(result[:content]).to be_an(Array)
      expect(result[:content].first).to eq({ text: 'Let me check the weather for you.' })
      expect(result[:content].last).to eq(
        toolUse: {
          toolUseId: 'tool_123',
          name: 'get_weather',
          input: { location: 'Boston' }
        }
      )
    end

    it 'formats tool call without text content' do
      tool_call = RubyLLM::ToolCall.new(
        id: 'tool_456',
        name: 'calculate',
        arguments: { expression: '2+2' }
      )
      message = RubyLLM::Message.new(
        role: :assistant,
        content: '',
        tool_calls: { 'tool_456' => tool_call }
      )

      result = described_class.format_converse_tool_call(message)

      expect(result[:content].length).to eq(1)
      expect(result[:content].first).to include(:toolUse)
    end

    it 'formats multiple tool calls' do
      tool_call1 = RubyLLM::ToolCall.new(id: 'tool_1', name: 'tool_one', arguments: { a: 1 })
      tool_call2 = RubyLLM::ToolCall.new(id: 'tool_2', name: 'tool_two', arguments: { b: 2 })
      message = RubyLLM::Message.new(
        role: :assistant,
        content: 'Using tools',
        tool_calls: { 'tool_1' => tool_call1, 'tool_2' => tool_call2 }
      )

      result = described_class.format_converse_tool_call(message)

      expect(result[:content].length).to eq(3) # text + 2 tool uses
      expect(result[:content][1][:toolUse][:name]).to eq('tool_one')
      expect(result[:content][2][:toolUse][:name]).to eq('tool_two')
    end

    it 'handles raw content' do
      raw_content = RubyLLM::Content::Raw.new([{ text: 'raw text' }])
      message = RubyLLM::Message.new(
        role: :assistant,
        content: raw_content
      )

      result = described_class.format_converse_tool_call(message)

      expect(result[:role]).to eq('assistant')
      expect(result[:content]).to eq([{ text: 'raw text' }])
    end
  end

  describe '.format_converse_tool_result' do
    it 'formats tool result with text content' do
      message = RubyLLM::Message.new(
        role: :tool,
        content: 'The weather is sunny, 72°F',
        tool_call_id: 'tool_123'
      )

      result = described_class.format_converse_tool_result(message)

      expect(result[:role]).to eq('user')
      expect(result[:content]).to be_an(Array)
      expect(result[:content].first).to eq(
        toolResult: {
          toolUseId: 'tool_123',
          content: [{ text: 'The weather is sunny, 72°F' }]
        }
      )
    end

    it 'handles raw content' do
      raw_content = RubyLLM::Content::Raw.new([{ toolResult: { toolUseId: 'tool_456', content: 'result' } }])
      message = RubyLLM::Message.new(
        role: :tool,
        content: raw_content,
        tool_call_id: 'tool_456'
      )

      result = described_class.format_converse_tool_result(message)

      expect(result[:role]).to eq('user')
      expect(result[:content]).to eq([{ toolResult: { toolUseId: 'tool_456', content: 'result' } }])
    end
  end

  describe '.format_message' do
    it 'routes to format_basic_message for regular messages' do
      message = RubyLLM::Message.new(role: :user, content: 'Hello')

      result = described_class.format_message(message)

      expect(result[:role]).to eq('user')
      expect(result[:content].first[:text]).to eq('Hello')
    end

    it 'routes to format_converse_tool_call for tool call messages' do
      tool_call = RubyLLM::ToolCall.new(id: 'tc1', name: 'test', arguments: {})
      message = RubyLLM::Message.new(
        role: :assistant,
        content: '',
        tool_calls: { 'tc1' => tool_call }
      )

      result = described_class.format_message(message)

      expect(result[:content].first).to include(:toolUse)
    end

    it 'routes to format_converse_tool_result for tool result messages' do
      message = RubyLLM::Message.new(
        role: :tool,
        content: 'result',
        tool_call_id: 'tc1'
      )

      result = described_class.format_message(message)

      expect(result[:content].first).to include(:toolResult)
    end
  end

  describe '.build_converse_system_content' do
    it 'returns nil for empty system messages' do
      result = chat_instance.send(:build_converse_system_content, [])
      expect(result).to be_nil
    end

    it 'formats single system message' do
      message = RubyLLM::Message.new(role: :system, content: 'You are helpful')

      result = chat_instance.send(:build_converse_system_content, [message])

      expect(result).to be_an(Array)
      expect(result.first).to eq({ text: 'You are helpful' })
    end

    it 'combines multiple system messages with warning' do
      msg1 = RubyLLM::Message.new(role: :system, content: 'Be helpful')
      msg2 = RubyLLM::Message.new(role: :system, content: 'Be concise')

      expect(RubyLLM.logger).to receive(:warn).with(/only supports a single system message/)

      result = chat_instance.send(:build_converse_system_content, [msg1, msg2])

      expect(result.length).to eq(2)
      expect(result[0][:text]).to eq('Be helpful')
      expect(result[1][:text]).to eq('Be concise')
    end

    it 'handles raw content in system messages' do
      raw_content = RubyLLM::Content::Raw.new([{ text: 'raw system prompt' }])
      message = RubyLLM::Message.new(role: :system, content: raw_content)

      result = chat_instance.send(:build_converse_system_content, [message])

      expect(result.first[:text]).to include('raw system prompt')
    end
  end

  describe '.render_payload' do
    let(:user_message) { RubyLLM::Message.new(role: :user, content: 'Hello') }
    let(:messages) { [user_message] }
    let(:tools) { {} }
    let(:temperature) { nil }

    it 'builds basic payload with messages' do
      payload = chat_instance.send(:render_payload,
        messages,
        tools: tools,
        temperature: temperature,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload[:messages]).to be_an(Array)
      expect(payload[:messages].first[:role]).to eq('user')
      expect(payload[:messages].first[:content].first[:text]).to eq('Hello')
    end

    it 'includes inferenceConfig with max tokens' do
      payload = chat_instance.send(:render_payload,
        messages,
        tools: tools,
        temperature: temperature,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload[:inferenceConfig]).to include(maxTokens: 8192)
    end

    it 'includes temperature when provided' do
      payload = chat_instance.send(:render_payload,
        messages,
        tools: tools,
        temperature: 0.7,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload[:inferenceConfig][:temperature]).to eq(0.7)
    end

    it 'does not include temperature when nil' do
      payload = chat_instance.send(:render_payload,
        messages,
        tools: tools,
        temperature: nil,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload[:inferenceConfig]).not_to have_key(:temperature)
    end

    it 'includes system content when system messages present' do
      system_msg = RubyLLM::Message.new(role: :system, content: 'Be helpful')
      msgs = [system_msg, user_message]

      payload = chat_instance.send(:render_payload,
        msgs,
        tools: tools,
        temperature: temperature,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload[:system]).to be_an(Array)
      expect(payload[:system].first[:text]).to eq('Be helpful')
    end

    it 'excludes system key when no system messages' do
      payload = chat_instance.send(:render_payload,
        messages,
        tools: tools,
        temperature: temperature,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload).not_to have_key(:system)
    end

    it 'includes tools in toolConfig when provided' do
      tool = instance_double(
        RubyLLM::Tool,
        name: 'get_weather',
        description: 'Get weather info',
        parameters: {},
        params_schema: nil,
        provider_params: {}
      )
      tools_hash = { get_weather: tool }

      payload = chat_instance.send(:render_payload,
        messages,
        tools: tools_hash,
        temperature: temperature,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload[:toolConfig]).to be_a(Hash)
      expect(payload[:toolConfig][:tools]).to be_an(Array)
      expect(payload[:toolConfig][:tools].first[:toolSpec][:name]).to eq('get_weather')
    end

    it 'uses default max tokens when model max_tokens is nil' do
      model_without_max = instance_double(RubyLLM::Model::Info, id: 'test', max_tokens: nil)

      payload = chat_instance.send(:render_payload,
        messages,
        tools: tools,
        temperature: temperature,
        model: model_without_max,
        stream: false,
        schema: nil
      )

      expect(payload[:inferenceConfig][:maxTokens]).to eq(4096)
    end
  end

  describe '.parse_converse_response' do
    it 'parses text-only response' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [
              { 'text' => 'Hello! How can I help you?' }
            ]
          }
        },
        'usage' => {
          'inputTokens' => 10,
          'outputTokens' => 8
        }
      }
      response = instance_double(Faraday::Response, body: response_body)

      message = chat_instance.send(:parse_converse_response, response)

      expect(message).to be_a(RubyLLM::Message)
      expect(message.role).to eq(:assistant)
      expect(message.content).to eq('Hello! How can I help you?')
      expect(message.input_tokens).to eq(10)
      expect(message.output_tokens).to eq(8)
      expect(message.tool_calls).to be_nil
    end

    it 'parses response with tool uses' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [
              { 'text' => 'Let me check that for you.' },
              {
                'toolUse' => {
                  'toolUseId' => 'tool_abc123',
                  'name' => 'get_weather',
                  'input' => { 'location' => 'Boston' }
                }
              }
            ]
          }
        },
        'usage' => {
          'inputTokens' => 15,
          'outputTokens' => 12
        }
      }
      response = instance_double(Faraday::Response, body: response_body)

      message = chat_instance.send(:parse_converse_response, response)

      expect(message.content).to eq('Let me check that for you.')
      expect(message.tool_calls).to be_a(Hash)
      expect(message.tool_calls['tool_abc123']).to be_a(RubyLLM::ToolCall)
      expect(message.tool_calls['tool_abc123'].name).to eq('get_weather')
      expect(message.tool_calls['tool_abc123'].arguments).to eq({ 'location' => 'Boston' })
    end

    it 'parses multiple tool uses' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [
              {
                'toolUse' => {
                  'toolUseId' => 'tool_1',
                  'name' => 'search',
                  'input' => { 'query' => 'ruby' }
                }
              },
              {
                'toolUse' => {
                  'toolUseId' => 'tool_2',
                  'name' => 'calculate',
                  'input' => { 'expression' => '2+2' }
                }
              }
            ]
          }
        },
        'usage' => {}
      }
      response = instance_double(Faraday::Response, body: response_body)

      message = chat_instance.send(:parse_converse_response, response)

      expect(message.tool_calls.keys).to contain_exactly('tool_1', 'tool_2')
    end

    it 'handles response with empty content' do
      response_body = {
        'output' => {
          'message' => {
            'content' => []
          }
        },
        'usage' => {}
      }
      response = instance_double(Faraday::Response, body: response_body)

      message = chat_instance.send(:parse_converse_response, response)

      expect(message.content).to eq('')
      expect(message.tool_calls).to be_nil
    end

    it 'handles missing usage data' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Response' }]
          }
        }
      }
      response = instance_double(Faraday::Response, body: response_body)

      message = chat_instance.send(:parse_converse_response, response)

      expect(message.input_tokens).to be_nil
      expect(message.output_tokens).to be_nil
    end
  end

  describe '.format_tool_for_converse' do
    it 'formats tool with parameters schema' do
      schema_hash = {
        type: 'object',
        properties: {
          location: { type: 'string', description: 'City name' }
        },
        required: ['location']
      }
      schema_def = RubyLLM::Tool::SchemaDefinition.new(schema: schema_hash)
      tool = instance_double(
        RubyLLM::Tool,
        name: 'get_weather',
        description: 'Get current weather',
        params_schema: schema_def.json_schema,
        parameters: {},
        provider_params: {}
      )

      result = chat_instance.send(:format_tool_for_converse, tool)

      expect(result[:toolSpec][:name]).to eq('get_weather')
      expect(result[:toolSpec][:description]).to eq('Get current weather')
      expect(result[:toolSpec][:inputSchema][:json]).to be_a(Hash)
      expect(result[:toolSpec][:inputSchema][:json]['type']).to eq('object')
    end

    it 'formats tool without parameters schema' do
      tool = instance_double(
        RubyLLM::Tool,
        name: 'simple_tool',
        description: 'A simple tool',
        params_schema: nil,
        parameters: { arg1: instance_double(RubyLLM::Parameter) },
        provider_params: {}
      )

      # Allow schema generation from parameters
      allow(RubyLLM::Tool::SchemaDefinition).to receive(:from_parameters).and_return(
        instance_double(RubyLLM::Tool::SchemaDefinition, json_schema: { type: 'object' })
      )

      result = chat_instance.send(:format_tool_for_converse, tool)

      expect(result[:toolSpec][:name]).to eq('simple_tool')
      expect(result[:toolSpec][:inputSchema][:json]).to be_a(Hash)
    end

    it 'uses default schema when no params_schema or parameters' do
      tool = instance_double(
        RubyLLM::Tool,
        name: 'no_params_tool',
        description: 'Tool with no params',
        params_schema: nil,
        parameters: {},
        provider_params: {}
      )

      allow(RubyLLM::Tool::SchemaDefinition).to receive(:from_parameters).and_return(nil)

      result = chat_instance.send(:format_tool_for_converse, tool)

      expect(result[:toolSpec][:inputSchema][:json]).to eq(
        RubyLLM::Providers::Anthropic::Tools.default_input_schema
      )
    end
  end
end
