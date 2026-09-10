require "rails_helper"

RSpec.describe "SPEC-016 upload guard drift inspection" do
  describe "the oversized copy (AT18, R16, AC-18)" do
    it "interpolates the cap in every namespace rather than stating a number" do
      # Arrange
      namespaces = %w[admin.home_page_content admin.about_page_content admin.gallery_photos]

      # Act
      raw_values = namespaces.index_with { |namespace|
        I18n.backend.send(:lookup, :en, "#{namespace}.oversized_image_alert")
      }

      # Assert
      expect(raw_values.values).to all(include("%{max_mb}"))
      expect(raw_values.values.grep(/\d+\s*MB/)).to be_empty
    end

    it "renders the current cap once interpolated" do
      # Arrange
      max_mb = ImageAttachmentValidatable::MAX_IMAGE_SIZE / 1.megabyte

      # Act
      message = I18n.t("admin.gallery_photos.oversized_image_alert", max_mb: max_mb)

      # Assert
      expect(message).to include("30 MB")
    end
  end

  describe "the Stimulus controller's sources of truth (AT18, R15)" do
    it "reads the cap and the type list from its values, never from a literal" do
      # Arrange
      controller_source = Rails.root.join("app/javascript/controllers/image_upload_guard_controller.js").read

      # Act
      multi_digit_literals = controller_source.scan(/\b\d{2,}\b/)
      mime_literals = controller_source.scan(%r{["'`]image/})

      # Assert
      expect(controller_source).to include("this.maxBytesValue")
      expect(controller_source).to include("this.allowedTypesValue")
      expect(multi_digit_literals).to be_empty
      expect(mime_literals).to be_empty
    end
  end

  describe "the server's rule is untouched (AT19, R18, AC-19)" do
    it "keeps the cap and the allowed type list at their pre-spec values" do
      # Arrange / Act
      cap = ImageAttachmentValidatable::MAX_IMAGE_SIZE
      allowed_types = ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES

      # Assert
      expect(cap).to eq(30.megabytes)
      expect(allowed_types).to contain_exactly("image/jpeg", "image/png", "image/webp")
    end
  end
end
