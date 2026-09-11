module ImageAttachmentValidatable
  extend ActiveSupport::Concern

  # Editing this list alone silently desyncs the admin file pickers' `accept` filter from the
  # server's actual rule: ALLOWED_IMAGE_EXTENSIONS below is the other half of that filter.
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  ALLOWED_IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze
  MAX_IMAGE_SIZE = 30.megabytes

  def self.accept_attribute_value
    (ALLOWED_IMAGE_TYPES + ALLOWED_IMAGE_EXTENSIONS).join(",")
  end

  class_methods do
    def validates_image_attachment(*attachment_names)
      attachment_names.each do |name|
        validate -> { validate_image_attachment(name) }
      end
    end
  end

  private

  def validate_image_attachment(name)
    attachment = public_send(name)
    return unless attachment.attached?

    unless attachment.blob.content_type.in?(ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES)
      errors.add(name, :invalid_content_type)
    end

    if attachment.blob.byte_size > ImageAttachmentValidatable::MAX_IMAGE_SIZE
      errors.add(name, :file_too_large)
    end
  end
end
