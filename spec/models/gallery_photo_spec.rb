require "rails_helper"

RSpec.describe GalleryPhoto, type: :model do
  describe "validations" do
    context "without an attached image" do
      it "is invalid with an error on image (AT8, AC-9, E4)" do
        # Arrange
        photo = GalleryPhoto.new(position: 0)

        # Act
        photo.valid?

        # Assert
        expect(photo.errors[:image]).to be_present
      end
    end

    context "with an attached image whose content type is not allowed" do
      it "is invalid with a content-type error on image (AT9, AC-10, E2)" do
        # Arrange
        photo = GalleryPhoto.new(position: 0)
        photo.image.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.svg")),
          filename: "gallery_photo.svg",
          content_type: "image/svg+xml"
        )

        # Act
        photo.valid?

        # Assert
        expect(photo.errors[:image]).to include(I18n.t("activerecord.errors.messages.invalid_content_type"))
      end
    end

    context "with an attached image exceeding the maximum size" do
      it "is invalid with a file-size error on image (AT10, AC-11, E3)" do
        # Arrange
        photo = GalleryPhoto.new(position: 0)
        photo.image.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.jpg")),
          filename: "gallery_photo.jpg",
          content_type: "image/jpeg"
        )
        allow(photo.image.blob).to receive(:byte_size).and_return(16.megabytes)

        # Act
        photo.valid?

        # Assert
        expect(photo.errors[:image]).to include(I18n.t("activerecord.errors.messages.file_too_large"))
      end
    end

    context "with a valid JPEG under 15 MB attached" do
      it "is valid with no errors (AT11, AC-12, E1)" do
        # Arrange
        photo = GalleryPhoto.new(position: 0)
        photo.image.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.jpg")),
          filename: "gallery_photo.jpg",
          content_type: "image/jpeg"
        )

        # Act
        result = photo.valid?

        # Assert
        expect(result).to be true
        expect(photo.errors).to be_empty
      end
    end
  end

  describe "#display_variant" do
    it "processes without raising a missing-processor error (AT7, AC-8)" do
      # Arrange
      photo = create(:gallery_photo)

      # Act & Assert
      expect { photo.display_variant.processed }.not_to raise_error
    end

    it "bounds a large image to 1200px on its long edge without cropping" do
      # Arrange
      photo = create(:gallery_photo, :large)

      # Act
      dimensions = processed_variant_dimensions(photo.display_variant)

      # Assert
      expect(dimensions).to eq([ 1200, 750 ])
    end
  end

  describe "#thumbnail_variant" do
    it "processes without raising a missing-processor error" do
      # Arrange
      photo = create(:gallery_photo, :large)

      # Act & Assert
      expect { photo.thumbnail_variant.processed }.not_to raise_error
    end

    it "crops a landscape image to a square matching the aspect-square grid tile" do
      # Arrange
      photo = create(:gallery_photo, :large)

      # Act
      dimensions = processed_variant_dimensions(photo.thumbnail_variant)

      # Assert
      expect(dimensions).to eq([ 600, 600 ])
    end

    it "encodes to fewer bytes than the display variant served to the lightbox" do
      # Arrange
      photo = create(:gallery_photo, :large)

      # Act
      thumbnail_bytes = photo.thumbnail_variant.processed.image.byte_size
      display_bytes = photo.display_variant.processed.image.byte_size

      # Assert
      expect(thumbnail_bytes).to be < display_bytes
    end
  end

  def processed_variant_dimensions(variant)
    image = Vips::Image.new_from_buffer(variant.processed.image.download, "")
    [ image.width, image.height ]
  end
end
