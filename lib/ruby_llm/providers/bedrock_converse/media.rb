# frozen_string_literal: true

module RubyLLM
  module Providers
    class BedrockConverse
      # Media handling methods for the Bedrock Converse API integration
      # NOTE: Bedrock does not support url attachments
      module Media
        extend Anthropic::Media

        module_function

        def format_content(content) # rubocop:disable Metrics/PerceivedComplexity
          return content.value if content.is_a?(RubyLLM::Content::Raw)
          return [Anthropic::Media.format_text(content.to_json)] if content.is_a?(Hash) || content.is_a?(Array)
          return [] if content.nil? # Return empty array for nil content
          return [Anthropic::Media.format_text(content)] unless content.is_a?(Content)

          parts = []
          parts << Anthropic::Media.format_text(content.text) if content.text

          # Track document names to ensure uniqueness
          document_names = Hash.new(0)

          content.attachments.each do |attachment|
            case attachment.type
            when :image
              parts << format_image(attachment)
            when :pdf
              # Generate unique name if needed
              base_name = attachment.filename
              document_names[base_name] += 1

              # Bedrock document names: Despite AWS docs saying "alphanumeric", periods appear to be rejected
              # Safe characters: alphanumeric, whitespace, hyphens, parentheses, square brackets (NO periods/underscores)
              # Remove extension to avoid period issues
              name_without_ext = File.basename(base_name, File.extname(base_name))

              unique_name = if document_names[base_name] > 1
                              # Add suffix for duplicates (use hyphen, not underscore)
                              "#{name_without_ext}-#{document_names[base_name] - 1}"
                            else
                              name_without_ext
                            end
              parts << format_pdf(attachment, unique_name)
            when :text
              parts << Anthropic::Media.format_text_file(attachment)
            else
              raise UnsupportedAttachmentError, attachment.type
            end
          end

          parts
        end

        def format_image(image)
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: image.mime_type,
              data: image.encoded
            }
          }
        end

        def format_pdf(pdf, name = nil)
          {
            type: 'document',
            source: {
              type: 'base64',
              media_type: pdf.mime_type,
              data: pdf.encoded
            },
            name: name || pdf.filename
          }
        end
      end
    end
  end
end
