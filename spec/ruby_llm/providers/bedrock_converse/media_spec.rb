# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::BedrockConverse::Media do
  describe '.format_content' do
    context 'with Raw content' do
      it 'returns the raw value directly' do
        raw_value = [{ type: 'image', source: { bytes: 'data' } }]
        raw_content = RubyLLM::Content::Raw.new(raw_value)

        result = described_class.format_content(raw_content)

        expect(result).to eq(raw_value)
      end
    end

    context 'with Hash content' do
      it 'formats as JSON text' do
        hash_content = { key: 'value', nested: { data: 123 } }

        result = described_class.format_content(hash_content)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first[:type]).to eq('text')
        expect(result.first[:text]).to eq(hash_content.to_json)
      end
    end

    context 'with Array content' do
      it 'formats as JSON text' do
        array_content = [1, 2, 3, 'test']

        result = described_class.format_content(array_content)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first[:type]).to eq('text')
        expect(result.first[:text]).to eq(array_content.to_json)
      end
    end

    context 'with String content' do
      it 'formats as text' do
        text_content = 'Hello, world!'

        result = described_class.format_content(text_content)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first[:type]).to eq('text')
        expect(result.first[:text]).to eq('Hello, world!')
      end
    end

    context 'with Content object containing only text' do
      it 'formats text as single element array' do
        content = RubyLLM::Content.new('Just text content')

        result = described_class.format_content(content)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first[:type]).to eq('text')
        expect(result.first[:text]).to eq('Just text content')
      end
    end

    context 'with Content object containing text and image attachment' do
      it 'formats both text and image' do
        content = RubyLLM::Content.new('Check this image')
        image_attachment = instance_double(
          RubyLLM::Attachment,
          type: :image,
          mime_type: 'image/png',
          encoded: 'base64imagedata'
        )
        allow(content).to receive(:attachments).and_return([image_attachment])

        result = described_class.format_content(content)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result[0][:type]).to eq('text')
        expect(result[0][:text]).to eq('Check this image')
        expect(result[1][:type]).to eq('image')
        expect(result[1][:source][:data]).to eq('base64imagedata')
      end
    end

    context 'with Content object containing text and PDF attachment' do
      it 'formats both text and PDF' do
        content = RubyLLM::Content.new('Analyze this document')
        pdf_attachment = instance_double(
          RubyLLM::Attachment,
          type: :pdf,
          mime_type: 'application/pdf',
          encoded: 'base64pdfdata',
          filename: 'document.pdf'
        )
        allow(content).to receive(:attachments).and_return([pdf_attachment])

        result = described_class.format_content(content)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result[0][:type]).to eq('text')
        expect(result[1][:type]).to eq('document')
        expect(result[1][:source][:media_type]).to eq('application/pdf')
        expect(result[1][:source][:data]).to eq('base64pdfdata')
      end
    end

    context 'with Content object containing text file attachment' do
      it 'formats text file using format_text_file' do
        content = RubyLLM::Content.new('Here is a text file')
        text_attachment = instance_double(
          RubyLLM::Attachment,
          type: :text,
          mime_type: 'text/plain'
        )
        allow(content).to receive(:attachments).and_return([text_attachment])
        allow(RubyLLM::Providers::Anthropic::Media).to receive(:format_text_file)
          .with(text_attachment)
          .and_return({ type: 'text', text: 'formatted text file content' })

        result = described_class.format_content(content)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result[1][:type]).to eq('text')
        expect(result[1][:text]).to eq('formatted text file content')
      end
    end

    context 'with Content object containing multiple attachments of mixed types' do
      it 'formats all attachments in order' do
        content = RubyLLM::Content.new('Multiple attachments')
        image = instance_double(RubyLLM::Attachment, type: :image, mime_type: 'image/jpeg', encoded: 'img1', filename: 'image.jpg')
        pdf = instance_double(RubyLLM::Attachment, type: :pdf, mime_type: 'application/pdf', encoded: 'pdf1', filename: 'doc.pdf')
        text_file = instance_double(RubyLLM::Attachment, type: :text, mime_type: 'text/plain', filename: 'file.txt')
        allow(content).to receive(:attachments).and_return([image, pdf, text_file])
        allow(RubyLLM::Providers::Anthropic::Media).to receive(:format_text_file)
          .with(text_file)
          .and_return({ type: 'text', text: 'text content' })

        result = described_class.format_content(content)

        expect(result.length).to eq(4) # text + 3 attachments
        expect(result[0][:type]).to eq('text')
        expect(result[1][:type]).to eq('image')
        expect(result[2][:type]).to eq('document')
        expect(result[3][:type]).to eq('text')
      end
    end

    context 'with Content object containing only attachments (no text)' do
      it 'formats only attachments' do
        # Create a temporary file to use as an attachment source
        require 'tempfile'
        Tempfile.create(['test_image', '.png']) do |file|
          file.write('fake image data')
          file.rewind

          content = RubyLLM::Content.new(nil, file.path)

          result = described_class.format_content(content)

          expect(result.length).to eq(1)
          expect(result[0][:type]).to eq('image')
        end
      end
    end
  end

  describe '.format_image' do
    context 'with base64 encoded image data' do
      it 'formats JPEG image correctly' do
        image = instance_double(
          RubyLLM::Attachment,
          mime_type: 'image/jpeg',
          encoded: 'base64encodedimagedata'
        )

        result = described_class.format_image(image)

        expect(result).to eq({
          type: 'image',
          source: {
            type: 'base64',
            media_type: 'image/jpeg',
            data: 'base64encodedimagedata'
          }
        })
      end

      it 'formats PNG image correctly' do
        image = instance_double(
          RubyLLM::Attachment,
          mime_type: 'image/png',
          encoded: 'pngbase64data'
        )

        result = described_class.format_image(image)

        expect(result[:source][:media_type]).to eq('image/png')
        expect(result[:source][:data]).to eq('pngbase64data')
      end

      it 'formats GIF image correctly' do
        image = instance_double(
          RubyLLM::Attachment,
          mime_type: 'image/gif',
          encoded: 'gifbase64data'
        )

        result = described_class.format_image(image)

        expect(result[:source][:media_type]).to eq('image/gif')
        expect(result[:source][:data]).to eq('gifbase64data')
      end

      it 'formats WebP image correctly' do
        image = instance_double(
          RubyLLM::Attachment,
          mime_type: 'image/webp',
          encoded: 'webpbase64data'
        )

        result = described_class.format_image(image)

        expect(result[:source][:media_type]).to eq('image/webp')
        expect(result[:source][:data]).to eq('webpbase64data')
      end
    end

    context 'with different encoding formats' do
      it 'handles empty encoded data' do
        image = instance_double(
          RubyLLM::Attachment,
          mime_type: 'image/png',
          encoded: ''
        )

        result = described_class.format_image(image)

        expect(result[:source][:data]).to eq('')
      end

      it 'handles very long encoded data' do
        long_data = 'A' * 100000
        image = instance_double(
          RubyLLM::Attachment,
          mime_type: 'image/jpeg',
          encoded: long_data
        )

        result = described_class.format_image(image)

        expect(result[:source][:data]).to eq(long_data)
      end

      it 'handles encoded data with special characters' do
        special_data = 'abc123+/=XYZ'
        image = instance_double(
          RubyLLM::Attachment,
          mime_type: 'image/png',
          encoded: special_data
        )

        result = described_class.format_image(image)

        expect(result[:source][:data]).to eq(special_data)
      end
    end

    it 'always uses base64 type in source' do
      image = instance_double(
        RubyLLM::Attachment,
        mime_type: 'image/jpeg',
        encoded: 'data'
      )

      result = described_class.format_image(image)

      expect(result[:source][:type]).to eq('base64')
    end

    it 'always uses image type' do
      image = instance_double(
        RubyLLM::Attachment,
        mime_type: 'image/png',
        encoded: 'data'
      )

      result = described_class.format_image(image)

      expect(result[:type]).to eq('image')
    end
  end

  describe '.format_pdf' do
    it 'formats PDF with correct structure' do
      pdf = instance_double(
        RubyLLM::Attachment,
        mime_type: 'application/pdf',
        encoded: 'base64pdfcontent',
        filename: 'document.pdf'
      )

      result = described_class.format_pdf(pdf)

      expect(result).to eq({
        type: 'document',
        name: 'document.pdf',
        source: {
          type: 'base64',
          media_type: 'application/pdf',
          data: 'base64pdfcontent'
        }
      })
    end

    it 'handles empty PDF data' do
      pdf = instance_double(
        RubyLLM::Attachment,
        mime_type: 'application/pdf',
        encoded: '',
        filename: 'empty.pdf'
      )

      result = described_class.format_pdf(pdf)

      expect(result[:source][:data]).to eq('')
    end

    it 'handles large PDF data' do
      large_pdf_data = 'B' * 500000
      pdf = instance_double(
        RubyLLM::Attachment,
        mime_type: 'application/pdf',
        encoded: large_pdf_data,
        filename: 'large.pdf'
      )

      result = described_class.format_pdf(pdf)

      expect(result[:source][:data]).to eq(large_pdf_data)
      expect(result[:source][:data].length).to eq(500000)
    end

    it 'always uses document type' do
      pdf = instance_double(
        RubyLLM::Attachment,
        mime_type: 'application/pdf',
        encoded: 'data',
        filename: 'test.pdf'
      )

      result = described_class.format_pdf(pdf)

      expect(result[:type]).to eq('document')
    end

    it 'always uses base64 source type' do
      pdf = instance_double(
        RubyLLM::Attachment,
        mime_type: 'application/pdf',
        encoded: 'data',
        filename: 'test.pdf'
      )

      result = described_class.format_pdf(pdf)

      expect(result[:source][:type]).to eq('base64')
    end

    it 'preserves mime_type from attachment' do
      pdf = instance_double(
        RubyLLM::Attachment,
        mime_type: 'application/pdf',
        encoded: 'data',
        filename: 'test.pdf'
      )

      result = described_class.format_pdf(pdf)

      expect(result[:source][:media_type]).to eq('application/pdf')
    end
  end

  describe 'UnsupportedAttachmentError scenarios' do
    context 'with unsupported attachment type' do
      it 'raises UnsupportedAttachmentError for video type' do
        content = RubyLLM::Content.new('Check this video')
        video_attachment = instance_double(
          RubyLLM::Attachment,
          type: :video,
          mime_type: 'video/mp4'
        )
        allow(content).to receive(:attachments).and_return([video_attachment])

        expect {
          described_class.format_content(content)
        }.to raise_error(RubyLLM::UnsupportedAttachmentError)
      end

      it 'raises UnsupportedAttachmentError for audio type' do
        content = RubyLLM::Content.new('Listen to this')
        audio_attachment = instance_double(
          RubyLLM::Attachment,
          type: :audio,
          mime_type: 'audio/mp3'
        )
        allow(content).to receive(:attachments).and_return([audio_attachment])

        expect {
          described_class.format_content(content)
        }.to raise_error(RubyLLM::UnsupportedAttachmentError)
      end

      it 'raises UnsupportedAttachmentError for unknown type' do
        content = RubyLLM::Content.new('Unknown attachment')
        unknown_attachment = instance_double(
          RubyLLM::Attachment,
          type: :unknown,
          mime_type: 'application/octet-stream'
        )
        allow(content).to receive(:attachments).and_return([unknown_attachment])

        expect {
          described_class.format_content(content)
        }.to raise_error(RubyLLM::UnsupportedAttachmentError)
      end

      it 'includes the attachment type in the error' do
        content = RubyLLM::Content.new('Unsupported')
        video_attachment = instance_double(
          RubyLLM::Attachment,
          type: :video,
          mime_type: 'video/mp4'
        )
        allow(content).to receive(:attachments).and_return([video_attachment])

        expect {
          described_class.format_content(content)
        }.to raise_error(RubyLLM::UnsupportedAttachmentError, /video/)
      end
    end

    context 'with mixed supported and unsupported attachments' do
      it 'raises error before processing all attachments' do
        content = RubyLLM::Content.new('Mixed types')
        image = instance_double(RubyLLM::Attachment, type: :image, mime_type: 'image/png', encoded: 'data')
        video = instance_double(RubyLLM::Attachment, type: :video, mime_type: 'video/mp4')
        allow(content).to receive(:attachments).and_return([image, video])

        expect {
          described_class.format_content(content)
        }.to raise_error(RubyLLM::UnsupportedAttachmentError)
      end
    end
  end
end
