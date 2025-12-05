# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Streaming::ContentExtraction do
  # Create a test class that includes the module
  let(:extractor) do
    klass = Class.new do
      include RubyLLM::Providers::Bedrock::Streaming::ContentExtraction
      attr_accessor :model_id

      def initialize
        @model_id = 'test-model-id'
      end
    end
    klass.new
  end

  describe '#json_delta?' do
    it 'returns truthy when data has delta.toolUse' do
      data = {
        'delta' => {
          'toolUse' => {
            'toolUseId' => 'tool_123',
            'name' => 'get_weather'
          }
        }
      }

      expect(extractor.json_delta?(data)).to be_truthy
    end

    it 'returns falsey when data has delta but no toolUse' do
      data = {
        'delta' => {
          'text' => 'Hello'
        }
      }

      expect(extractor.json_delta?(data)).to be_falsey
    end

    it 'returns falsey when data has no delta' do
      data = {
        'output' => {
          'message' => 'Hello'
        }
      }

      expect(extractor.json_delta?(data)).to be_falsey
    end

    it 'raises error for nil data (current implementation does not handle nil)' do
      expect { extractor.json_delta?(nil) }.to raise_error(NoMethodError)
    end

    it 'returns falsey for empty hash' do
      expect(extractor.json_delta?({})).to be_falsey
    end
  end

  describe '#extract_streaming_content' do
    it 'extracts text from delta.text' do
      data = {
        'delta' => {
          'text' => 'Hello, world!'
        }
      }

      result = extractor.extract_streaming_content(data)

      expect(result).to eq('Hello, world!')
    end

    it 'returns empty string when delta has no text' do
      data = {
        'delta' => {
          'toolUse' => {
            'toolUseId' => 'tool_123'
          }
        }
      }

      result = extractor.extract_streaming_content(data)

      expect(result).to eq('')
    end

    it 'returns empty string when there is no delta' do
      data = {
        'output' => {
          'message' => 'Something'
        }
      }

      result = extractor.extract_streaming_content(data)

      expect(result).to eq('')
    end

    it 'returns empty string for nil data' do
      result = extractor.extract_streaming_content(nil)

      expect(result).to eq('')
    end

    it 'returns empty string for non-hash data' do
      result = extractor.extract_streaming_content('not a hash')

      expect(result).to eq('')
    end

    it 'handles empty delta.text' do
      data = {
        'delta' => {
          'text' => ''
        }
      }

      result = extractor.extract_streaming_content(data)

      expect(result).to eq('')
    end

    it 'handles nil delta.text' do
      data = {
        'delta' => {
          'text' => nil
        }
      }

      result = extractor.extract_streaming_content(data)

      expect(result).to eq('')
    end

    it 'converts text to string' do
      data = {
        'delta' => {
          'text' => 123
        }
      }

      result = extractor.extract_streaming_content(data)

      expect(result).to eq('123')
    end
  end

  describe '#extract_tool_calls' do
    it 'extracts tool call from delta.toolUse' do
      data = {
        'delta' => {
          'toolUse' => {
            'toolUseId' => 'tool_abc123',
            'name' => 'get_weather'
          }
        }
      }

      result = extractor.extract_tool_calls(data)

      expect(result).to be_a(Hash)
      expect(result['tool_abc123']).to be_a(RubyLLM::ToolCall)
      expect(result['tool_abc123'].id).to eq('tool_abc123')
      expect(result['tool_abc123'].name).to eq('get_weather')
      expect(result['tool_abc123'].arguments).to eq({})
    end

    it 'returns nil when there is no delta' do
      data = {
        'output' => {
          'message' => 'Something'
        }
      }

      result = extractor.extract_tool_calls(data)

      expect(result).to be_nil
    end

    it 'returns nil when delta has no toolUse' do
      data = {
        'delta' => {
          'text' => 'Hello'
        }
      }

      result = extractor.extract_tool_calls(data)

      expect(result).to be_nil
    end

    it 'raises error for nil data (current implementation does not handle nil)' do
      expect { extractor.extract_tool_calls(nil) }.to raise_error(NoMethodError)
    end

    it 'returns nil for empty hash' do
      result = extractor.extract_tool_calls({})

      expect(result).to be_nil
    end

    it 'creates ToolCall with empty arguments hash' do
      data = {
        'delta' => {
          'toolUse' => {
            'toolUseId' => 'tool_456',
            'name' => 'calculate'
          }
        }
      }

      result = extractor.extract_tool_calls(data)

      expect(result['tool_456'].arguments).to eq({})
    end
  end

  describe '#extract_model_id' do
    it 'returns the instance model_id' do
      result = extractor.extract_model_id({})

      expect(result).to eq('test-model-id')
    end

    it 'ignores data parameter and uses instance variable' do
      data = {
        'modelId' => 'different-model'
      }

      result = extractor.extract_model_id(data)

      expect(result).to eq('test-model-id')
    end
  end

  describe '#extract_input_tokens' do
    it 'extracts inputTokens from usage' do
      data = {
        'usage' => {
          'inputTokens' => 42
        }
      }

      result = extractor.extract_input_tokens(data)

      expect(result).to eq(42)
    end

    it 'returns nil when usage is missing' do
      data = {}

      result = extractor.extract_input_tokens(data)

      expect(result).to be_nil
    end

    it 'returns nil when inputTokens is missing' do
      data = {
        'usage' => {
          'outputTokens' => 10
        }
      }

      result = extractor.extract_input_tokens(data)

      expect(result).to be_nil
    end

    it 'handles zero tokens' do
      data = {
        'usage' => {
          'inputTokens' => 0
        }
      }

      result = extractor.extract_input_tokens(data)

      expect(result).to eq(0)
    end
  end

  describe '#extract_output_tokens' do
    it 'extracts outputTokens from usage' do
      data = {
        'usage' => {
          'outputTokens' => 58
        }
      }

      result = extractor.extract_output_tokens(data)

      expect(result).to eq(58)
    end

    it 'returns nil when usage is missing' do
      data = {}

      result = extractor.extract_output_tokens(data)

      expect(result).to be_nil
    end

    it 'returns nil when outputTokens is missing' do
      data = {
        'usage' => {
          'inputTokens' => 10
        }
      }

      result = extractor.extract_output_tokens(data)

      expect(result).to be_nil
    end

    it 'handles zero tokens' do
      data = {
        'usage' => {
          'outputTokens' => 0
        }
      }

      result = extractor.extract_output_tokens(data)

      expect(result).to eq(0)
    end
  end

  describe '#extract_cached_tokens' do
    it 'returns nil (not supported in Converse API)' do
      data = {
        'usage' => {
          'cachedTokens' => 100
        }
      }

      result = extractor.extract_cached_tokens(data)

      expect(result).to be_nil
    end

    it 'returns nil for any data' do
      result = extractor.extract_cached_tokens({})

      expect(result).to be_nil
    end
  end

  describe '#extract_cache_creation_tokens' do
    it 'returns nil (not supported in Converse API)' do
      data = {
        'usage' => {
          'cacheCreationTokens' => 50
        }
      }

      result = extractor.extract_cache_creation_tokens(data)

      expect(result).to be_nil
    end

    it 'returns nil for any data' do
      result = extractor.extract_cache_creation_tokens({})

      expect(result).to be_nil
    end
  end

  describe 'integration: extracting from realistic streaming data' do
    it 'extracts text content from typical text chunk' do
      data = {
        'delta' => {
          'text' => 'The weather '
        },
        'usage' => {
          'inputTokens' => 15,
          'outputTokens' => 2
        }
      }

      content = extractor.extract_streaming_content(data)
      input_tokens = extractor.extract_input_tokens(data)
      output_tokens = extractor.extract_output_tokens(data)

      expect(content).to eq('The weather ')
      expect(input_tokens).to eq(15)
      expect(output_tokens).to eq(2)
    end

    it 'extracts tool call from tool use chunk' do
      data = {
        'delta' => {
          'toolUse' => {
            'toolUseId' => 'tool_weather_123',
            'name' => 'get_weather'
          }
        }
      }

      tool_calls = extractor.extract_tool_calls(data)
      content = extractor.extract_streaming_content(data)

      expect(tool_calls).not_to be_nil
      expect(tool_calls['tool_weather_123'].name).to eq('get_weather')
      expect(content).to eq('') # No text in tool use chunk
    end

    it 'handles chunk with only usage data' do
      data = {
        'usage' => {
          'inputTokens' => 50,
          'outputTokens' => 25
        }
      }

      content = extractor.extract_streaming_content(data)
      tool_calls = extractor.extract_tool_calls(data)
      input_tokens = extractor.extract_input_tokens(data)
      output_tokens = extractor.extract_output_tokens(data)

      expect(content).to eq('')
      expect(tool_calls).to be_nil
      expect(input_tokens).to eq(50)
      expect(output_tokens).to eq(25)
    end

    it 'handles empty delta' do
      data = {
        'delta' => {}
      }

      content = extractor.extract_streaming_content(data)
      tool_calls = extractor.extract_tool_calls(data)

      expect(content).to eq('')
      expect(tool_calls).to be_nil
    end
  end
end
