# Bedrock Converse API Migration

This document summarizes the migration from Bedrock's Anthropic-specific `invoke` API to the universal `converse` API.

## Overview

The Bedrock Converse API is a unified interface that works across all models in Bedrock, providing a consistent request/response format regardless of the underlying model provider.

## Key Changes

### 1. API Endpoints

**Before (Anthropic-specific):**
- Sync: `model/{modelId}/invoke`
- Streaming: `model/{modelId}/invoke-with-response-stream`

**After (Universal Converse):**
- Sync: `model/{modelId}/converse`
- Streaming: `model/{modelId}/converse-stream`

**Note:** The model ID remains in the URL path (not moved to request body).

### 2. Request Payload Structure

**Before:**
```json
{
  "anthropic_version": "bedrock-2023-05-31",
  "messages": [...],
  "max_tokens": 4096,
  "system": "...",
  "tools": [...]
}
```

**After:**
```json
{
  "messages": [...],
  "inferenceConfig": {
    "maxTokens": 4096,
    "temperature": 0.7
  },
  "system": [{"text": "..."}],
  "toolConfig": {
    "tools": [{"toolSpec": {...}}]
  }
}
```

### 3. Response Structure

**Sync Response Before:**
```json
{
  "content": [{"text": "..."}],
  "usage": {
    "input_tokens": 10,
    "output_tokens": 20
  }
}
```

**Sync Response After:**
```json
{
  "output": {
    "message": {
      "content": [{"text": "..."}],
      "role": "assistant"
    }
  },
  "usage": {
    "inputTokens": 10,
    "outputTokens": 20
  }
}
```

### 4. Streaming Format

**Before (Base64-encoded):**
```json
{
  "bytes": "eyJ0eXBlIjogImNvbnRlbnRfYmxvY2tfZGVsdGEiLCAiZGVsdGEiOiB7InRleHQiOiAiSGVsbG8ifX0="
}
```
After decoding:
```json
{
  "type": "content_block_delta",
  "delta": {"text": "Hello"}
}
```

**After (Direct JSON):**
```json
{
  "delta": {"text": "Hello"},
  "contentBlockIndex": 0
}
```

## Files Modified

1. **lib/ruby_llm/providers/bedrock/chat.rb**
   - Updated `completion_url` to use `/converse` endpoint
   - Changed payload structure to match Converse API format
   - Updated response parsing for new structure
   - Message formatting for tools and content

2. **lib/ruby_llm/providers/bedrock/streaming/base.rb**
   - Updated `stream_url` to use `/converse-stream` endpoint

3. **lib/ruby_llm/providers/bedrock/streaming/content_extraction.rb**
   - Simplified content extraction (direct `delta.text` access)
   - Updated token extraction paths

4. **lib/ruby_llm/providers/bedrock/streaming/payload_processing.rb**
   - Added support for direct JSON (no base64 decoding needed)
   - Kept backward compatibility with old format

5. **lib/ruby_llm/models.rb**
   - Added `provider/model` format parsing
   - Added automatic model ID resolution for Bedrock when using `bedrock/` prefix

## Benefits of Converse API

1. **Universal Interface**: Same API works with all Bedrock models (Claude, Llama, Mistral, Nova, etc.)
2. **Simpler Streaming**: No base64 encoding/decoding overhead
3. **Consistent Format**: Tool calling and content structure is standardized
4. **Better Support**: Recommended by AWS for all new integrations

## Testing

Run the test scripts to verify the migration:

```bash
# Test URL format
bundle exec ruby test_converse.rb

# Test with live Bedrock (requires AWS credentials)
aws-vault exec your-profile -- bundle exec ruby test_converse_live.rb

# Debug raw responses
aws-vault exec your-profile -- bundle exec ruby test_converse_debug.rb

# Debug streaming
aws-vault exec your-profile -- bundle exec ruby test_stream_debug.rb
```

## Using Bedrock Model IDs

You can use any Bedrock model ID with the `bedrock/` prefix:

```ruby
# Using aliases (recommended for common models)
chat = RubyLLM.chat(model: 'bedrock/nova-2-lite')
chat = RubyLLM.chat(model: 'bedrock/llama-4-scout-17b')

# Using full model IDs (for models not in aliases)
chat = RubyLLM.chat(model: 'bedrock/global.amazon.nova-2-lite-v1:0')
chat = RubyLLM.chat(model: 'bedrock/us.meta.llama4-scout-17b-instruct-v1:0')

# The system will automatically:
# 1. Parse the provider prefix
# 2. Try to resolve via aliases
# 3. If not found, accept the raw model ID
# 4. Create appropriate Model::Info with assumed capabilities
```

## Backward Compatibility

The changes maintain backward compatibility:
- Old streaming format (base64-encoded) still works
- Existing model IDs in the registry continue to work
- Non-Bedrock providers are unaffected

## Image and Document Support

The Converse API implementation fully supports multimodal inputs:

### Supported Image Formats
- JPEG (`image/jpeg`)
- PNG (`image/png`)
- GIF (`image/gif`)
- WebP (`image/webp`)

### Supported Document Formats
- PDF (`application/pdf`)
- CSV (`text/csv`)
- DOC/DOCX (`application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`)
- XLS/XLSX (`application/vnd.ms-excel`, `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`)
- HTML (`text/html`)
- TXT (`text/plain`)
- Markdown (`text/markdown`)

### Usage

```ruby
# Single image
chat = RubyLLM.chat(model: 'bedrock/model-id')
response = chat.ask("What's in this image?", with: '/path/to/image.jpg')

# Multiple images with Content (pass as array)
content = RubyLLM::Content.new(
  "Compare these images",
  ['/path/to/image1.jpg', '/path/to/image2.png']
)
response = chat.ask(content)

# Documents
response = chat.ask("Summarize this document", with: '/path/to/document.pdf')
```

Images and documents are automatically base64-encoded and sent with proper format metadata in the Converse API format.

## Migration Notes

- Cache token tracking is not available in Converse API (returns `nil`)
- Model ID is not returned in the response (use `@model_id` from request)
- System messages must be array of `{text: "..."}` objects
- Tool configuration uses `toolSpec` wrapper with `inputSchema: {json: ...}` structure
- Image and document attachments are fully supported with automatic format detection

## Tool Calling Behavior

The Converse API successfully handles tool calling across all models, but **model behavior varies**:

- **Claude models**: Excellent tool calling support. Will call tools and provide proper text responses.
- **Meta Llama models**: May get stuck in tool-calling loops, repeatedly calling the same tool without providing a final text response. This is a model limitation, not an API issue.
- **Other models**: Tool calling support varies by model.

The Converse API implementation correctly:
- ✅ Sends tool configuration in the correct format
- ✅ Receives tool use requests from models
- ✅ Executes tools and sends results back
- ✅ Formats tool results correctly

If a model gets stuck calling tools repeatedly, this indicates the model doesn't understand when to stop and provide a text response. Use models with better tool calling support (e.g., Claude).

### Max Tool Iterations Safety Feature

To prevent infinite tool-calling loops, the `Chat` class now includes a `max_tool_iterations` parameter (default: 10):

```ruby
# Default behavior (max 10 tool iterations)
chat = RubyLLM.chat(model: 'bedrock/some-model')

# Custom limit
chat = RubyLLM.chat(model: 'bedrock/some-model', max_tool_iterations: 5)

# Disable limit (use with caution!)
chat = RubyLLM.chat(model: 'bedrock/some-model', max_tool_iterations: nil)

# Change limit after creation
chat.max_tool_iterations = 20
```

When the limit is exceeded, a `RubyLLM::Error` is raised with a helpful message. This prevents your application from hanging when using models with poor tool calling support.
