require "rails_helper"

RSpec.describe ImageAttachmentValidatable do
  describe ".accept_attribute_value" do
    it "lists every allowed MIME type and extension, and nothing else (AT1, R1, R4, AC-1)" do
      # Arrange / Act
      accept_value = described_class.accept_attribute_value

      # Assert
      expect(accept_value.split(",")).to contain_exactly(
        "image/jpeg", "image/png", "image/webp", ".jpg", ".jpeg", ".png", ".webp"
      )
    end

    it "orders MIME types ahead of extensions (AT1, R4)" do
      # Arrange / Act
      accept_value = described_class.accept_attribute_value

      # Assert
      expect(accept_value).to eq("image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp")
    end

    context "when ALLOWED_IMAGE_TYPES gains a member" do
      it "reflects the new MIME type with no other code edited (AT2, R3, AC-2)" do
        # Arrange
        stub_const(
          "#{described_class}::ALLOWED_IMAGE_TYPES",
          described_class::ALLOWED_IMAGE_TYPES + [ "image/avif" ]
        )

        # Act
        accept_value = described_class.accept_attribute_value

        # Assert
        expect(accept_value.split(",")).to include("image/avif")
      end
    end

    context "when ALLOWED_IMAGE_TYPES loses a member" do
      it "drops the removed MIME type with no other code edited (AT2, R3, AC-2)" do
        # Arrange
        stub_const("#{described_class}::ALLOWED_IMAGE_TYPES", [ "image/png" ])

        # Act
        accept_value = described_class.accept_attribute_value

        # Assert
        expect(accept_value.split(",")).not_to include("image/jpeg")
      end
    end
  end

  describe "::ALLOWED_IMAGE_EXTENSIONS" do
    it "spells JPEG both ways so a strict extension filter hides neither (R1)" do
      # Arrange / Act
      extensions = described_class::ALLOWED_IMAGE_EXTENSIONS

      # Assert
      expect(extensions).to include(".jpg", ".jpeg")
    end

    it "is frozen" do
      expect(described_class::ALLOWED_IMAGE_EXTENSIONS).to be_frozen
    end
  end
end
