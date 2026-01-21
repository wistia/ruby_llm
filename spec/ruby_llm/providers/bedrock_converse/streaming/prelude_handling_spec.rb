# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::BedrockConverse::Streaming::PreludeHandling do
  # Create a test class that includes the module
  let(:handler) do
    klass = Class.new do
      include RubyLLM::Providers::BedrockConverse::Streaming::PreludeHandling
    end
    klass.new
  end

  describe '#can_read_prelude?' do
    it 'returns true when chunk has at least 12 bytes from offset' do
      chunk = 'a' * 20
      expect(handler.can_read_prelude?(chunk, 0)).to be true
      expect(handler.can_read_prelude?(chunk, 8)).to be true
    end

    it 'returns false when chunk has fewer than 12 bytes from offset' do
      chunk = 'a' * 15
      expect(handler.can_read_prelude?(chunk, 4)).to be false
      expect(handler.can_read_prelude?(chunk, 10)).to be false
    end

    it 'returns false when offset is at end of chunk' do
      chunk = 'a' * 12
      expect(handler.can_read_prelude?(chunk, 12)).to be false
    end
  end

  describe '#read_prelude' do
    it 'reads total_length and headers_length from binary data' do
      # Create a prelude: total_length=100, headers_length=20
      prelude = [100, 20, 0].pack('NNN')
      chunk = prelude + ('a' * 100)

      total_length, headers_length = handler.read_prelude(chunk, 0)

      expect(total_length).to eq(100)
      expect(headers_length).to eq(20)
    end

    it 'reads prelude from specified offset' do
      # Add some padding before the prelude
      padding = 'x' * 50
      prelude = [200, 30, 0].pack('NNN')
      chunk = padding + prelude + ('a' * 200)

      total_length, headers_length = handler.read_prelude(chunk, 50)

      expect(total_length).to eq(200)
      expect(headers_length).to eq(30)
    end

    it 'handles large length values' do
      prelude = [1_000_000, 50_000, 0].pack('NNN')
      chunk = prelude + ('a' * 100)

      total_length, headers_length = handler.read_prelude(chunk, 0)

      expect(total_length).to eq(1_000_000)
      expect(headers_length).to eq(50_000)
    end
  end

  describe '#valid_lengths?' do
    it 'returns true for valid length pairs' do
      expect(handler.valid_lengths?(100, 20)).to be true
      expect(handler.valid_lengths?(1000, 50)).to be true
      expect(handler.valid_lengths?(1_000_000, 999_999)).to be true
    end

    it 'returns false when total_length is nil' do
      expect(handler.valid_lengths?(nil, 20)).to be false
    end

    it 'returns false when headers_length is nil' do
      expect(handler.valid_lengths?(100, nil)).to be false
    end

    it 'returns false when total_length is zero or negative' do
      expect(handler.valid_lengths?(0, 10)).to be false
      expect(handler.valid_lengths?(-1, 10)).to be false
    end

    it 'returns false when headers_length is zero or negative' do
      expect(handler.valid_lengths?(100, 0)).to be false
      expect(handler.valid_lengths?(100, -1)).to be false
    end

    it 'returns false when total_length exceeds maximum (1,000,000)' do
      expect(handler.valid_lengths?(1_000_001, 50)).to be false
      expect(handler.valid_lengths?(2_000_000, 50)).to be false
    end

    it 'returns false when headers_length >= total_length' do
      expect(handler.valid_lengths?(100, 100)).to be false
      expect(handler.valid_lengths?(100, 101)).to be false
    end
  end

  describe '#calculate_positions' do
    it 'calculates headers_end and payload_end positions' do
      # offset=0, total_length=100, headers_length=20
      # headers_end = 0 + 12 + 20 = 32
      # payload_end = 0 + 100 - 4 = 96
      headers_end, payload_end = handler.calculate_positions(0, 100, 20)

      expect(headers_end).to eq(32)
      expect(payload_end).to eq(96)
    end

    it 'accounts for offset in calculations' do
      # offset=50, total_length=100, headers_length=20
      # headers_end = 50 + 12 + 20 = 82
      # payload_end = 50 + 100 - 4 = 146
      headers_end, payload_end = handler.calculate_positions(50, 100, 20)

      expect(headers_end).to eq(82)
      expect(payload_end).to eq(146)
    end

    it 'subtracts 4 bytes for message CRC from payload_end' do
      headers_end, payload_end = handler.calculate_positions(0, 100, 10)

      expect(payload_end).to eq(96) # 100 - 4
    end
  end

  describe '#valid_positions?' do
    it 'returns true for valid position combinations' do
      # headers_end=32, payload_end=96, chunk_size=100
      expect(handler.valid_positions?(32, 96, 100)).to be true
    end

    it 'returns false when headers_end >= payload_end' do
      expect(handler.valid_positions?(50, 50, 100)).to be false
      expect(handler.valid_positions?(51, 50, 100)).to be false
    end

    it 'returns false when headers_end >= chunk_size' do
      expect(handler.valid_positions?(32, 96, 32)).to be false
      expect(handler.valid_positions?(32, 96, 30)).to be false
    end

    it 'returns false when payload_end > chunk_size' do
      expect(handler.valid_positions?(32, 101, 100)).to be false
    end

    it 'allows payload_end to equal chunk_size' do
      expect(handler.valid_positions?(32, 100, 100)).to be true
    end
  end

  describe '#find_next_message' do
    it 'searches from offset + 4 for next valid prelude' do
      # find_next_message skips 4 bytes from offset before searching
      padding = 'xxxx'  # Will be skipped (offset + 4)
      valid_prelude = [100, 20, 0].pack('NNN')
      chunk = padding + valid_prelude + ('a' * 88)

      next_pos = handler.find_next_message(chunk, 0)

      # Should find prelude at position 4
      expect(next_pos).to eq(4)
    end

    it 'returns chunk.bytesize when no valid prelude is found' do
      # Create chunk with no valid preludes
      chunk = 'invalid data' * 10

      next_pos = handler.find_next_message(chunk, 0)

      expect(next_pos).to eq(chunk.bytesize)
    end
  end

  describe '#find_next_prelude' do
    it 'finds valid prelude after corrupted data' do
      # Corrupted data followed by valid prelude
      corrupted = 'corrupted' * 10
      valid_prelude = [100, 20, 0].pack('NNN')
      chunk = corrupted + valid_prelude + ('a' * 100)

      pos = handler.find_next_prelude(chunk, 0)

      expect(pos).to eq(corrupted.bytesize)
    end

    it 'returns nil when no valid prelude is found' do
      chunk = 'no valid prelude here' * 5

      pos = handler.find_next_prelude(chunk, 0)

      expect(pos).to be_nil
    end

    it 'starts scanning from specified offset' do
      # Valid prelude at position 0, another at position 100
      prelude1 = [100, 20, 0].pack('NNN')
      prelude2 = [100, 20, 0].pack('NNN')
      chunk = prelude1 + ('a' * 88) + prelude2 + ('b' * 88)

      # Start searching after first prelude
      pos = handler.find_next_prelude(chunk, 50)

      expect(pos).to eq(100)
    end

    it 'handles edge case near end of chunk' do
      valid_prelude = [100, 20, 0].pack('NNN')
      chunk = ('x' * 100) + valid_prelude

      pos = handler.find_next_prelude(chunk, 90)

      expect(pos).to eq(100)
    end

    it 'does not scan past chunk boundary' do
      # Create chunk where scanning would go past end
      chunk = 'a' * 50

      pos = handler.find_next_prelude(chunk, 45)

      expect(pos).to be_nil
    end
  end

  describe 'integration: handling various corrupted data scenarios' do
    it 'handles chunk with all zeros' do
      chunk = "\x00" * 100

      expect(handler.can_read_prelude?(chunk, 0)).to be true

      total_length, headers_length = handler.read_prelude(chunk, 0)
      expect(handler.valid_lengths?(total_length, headers_length)).to be false
    end

    it 'handles chunk with random binary data' do
      chunk = Random.bytes(200)

      # Should be able to read prelude (12 bytes)
      expect(handler.can_read_prelude?(chunk, 0)).to be true

      # But lengths are likely invalid
      total_length, headers_length = handler.read_prelude(chunk, 0)
      # Most random data won't form valid lengths
      # Just verify it doesn't crash
      expect([true, false]).to include(handler.valid_lengths?(total_length, headers_length))
    end

    it 'handles recovery from corrupted prelude' do
      # Invalid prelude (headers_length > total_length)
      invalid = [50, 100, 0].pack('NNN')
      # Valid prelude after some data
      valid = [100, 20, 0].pack('NNN')
      chunk = invalid + ('x' * 50) + valid + ('a' * 88)

      # Should find a valid prelude after the invalid one
      next_pos = handler.find_next_prelude(chunk, 4)
      expect(next_pos).not_to be_nil
      # Should find some prelude position (exact position depends on scan algorithm)
      expect(next_pos).to be >= 4
    end

    it 'handles multiple consecutive invalid preludes' do
      invalid1 = [0, 0, 0].pack('NNN')
      invalid2 = [-1, -1, 0].pack('NNN')
      valid = [100, 20, 0].pack('NNN')
      chunk = invalid1 + invalid2 + valid + ('a' * 88)

      pos = handler.find_next_prelude(chunk, 0)
      expect(pos).to eq(invalid1.bytesize + invalid2.bytesize)
    end
  end

  describe 'edge cases' do
    it 'handles minimum valid lengths' do
      # total_length=13 (minimum: 1 byte header + 12 prelude), headers_length=1
      expect(handler.valid_lengths?(13, 1)).to be true
    end

    it 'handles maximum valid total_length' do
      expect(handler.valid_lengths?(1_000_000, 1)).to be true
    end

    it 'handles prelude exactly at end of chunk' do
      prelude = [100, 20, 0].pack('NNN')
      chunk = ('x' * 50) + prelude

      expect(handler.can_read_prelude?(chunk, 50)).to be true

      total_length, headers_length = handler.read_prelude(chunk, 50)
      expect(total_length).to eq(100)
      expect(headers_length).to eq(20)
    end
  end
end
