require "rails_helper"

RSpec.describe AboutPageContent, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:shop_heading) }
    it { is_expected.to validate_presence_of(:shop_phone_label) }
    it { is_expected.to validate_presence_of(:shop_phone_number) }
    it { is_expected.to validate_presence_of(:shop_address_label) }
    it { is_expected.to validate_presence_of(:shop_address) }
    it { is_expected.to validate_presence_of(:bio_heading) }
    it { is_expected.to validate_presence_of(:bio_body) }
    it { is_expected.to validate_presence_of(:slideshow_alt_1) }
    it { is_expected.to validate_presence_of(:slideshow_alt_2) }
    it { is_expected.to validate_presence_of(:slideshow_alt_3) }

    it "is valid with all required fields" do
      # Arrange / Act
      record = build(:about_page_content)

      # Assert
      expect(record).to be_valid
    end

    it "rejects bio_body with all-whitespace (E9)" do
      # Arrange
      record = build(:about_page_content, bio_body: "   ")

      # Act
      record.valid?

      # Assert
      expect(record.errors[:bio_body]).to be_present
    end

    describe "slideshow alt fields presence (E11)" do
      it "rejects blank slideshow_alt_1 without affecting the other two fields' validity" do
        # Arrange
        record = build(:about_page_content, slideshow_alt_1: "")

        # Act
        record.valid?

        # Assert
        expect(record.errors[:slideshow_alt_1]).to be_present
        expect(record.errors[:slideshow_alt_2]).to be_empty
        expect(record.errors[:slideshow_alt_3]).to be_empty
      end
    end

    describe "shop_phone_number format (R7)" do
      it "is valid with digits, spaces, hyphens, parentheses, and a leading plus" do
        # Arrange
        record = build(:about_page_content, shop_phone_number: "+1 (208) 251-9536")

        # Act / Assert
        expect(record).to be_valid
      end

      it "rejects a value containing letters (E4)" do
        # Arrange
        record = build(:about_page_content, shop_phone_number: "call-us-now")

        # Act
        record.valid?

        # Assert
        expect(record.errors[:shop_phone_number]).to be_present
      end

      it "rejects a value of formatting punctuation with no digit (E6)" do
        # Arrange
        record = build(:about_page_content, shop_phone_number: "----")

        # Act
        record.valid?

        # Assert
        expect(record.errors[:shop_phone_number]).to be_present
      end

      it "rejects a blank value (E5)" do
        # Arrange
        record = build(:about_page_content, shop_phone_number: "")

        # Act
        record.valid?

        # Assert
        expect(record.errors[:shop_phone_number]).to be_present
      end
    end
  end

  describe "slideshow image attachments (R1, R2)" do
    it "is valid with no slots attached — presence is not required (AT17, R2)" do
      # Arrange
      record = build(:about_page_content)

      # Act
      result = record.valid?

      # Assert
      expect(result).to be true
      expect(record.errors[:slideshow_image_1]).to be_empty
      expect(record.errors[:slideshow_image_2]).to be_empty
      expect(record.errors[:slideshow_image_3]).to be_empty
    end

    it "is valid with a JPEG under the size cap and pixel dimensions smaller than 400x400 attached (AT17, R12)" do
      # Arrange
      record = build(:about_page_content)
      record.slideshow_image_1.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.jpg")),
        filename: "gallery_photo.jpg",
        content_type: "image/jpeg"
      )

      # Act
      result = record.valid?

      # Assert
      expect(result).to be true
      expect(record.errors[:slideshow_image_1]).to be_empty
    end

    it "rejects an image/svg+xml content type on slideshow_image_2 (AT6, R2, E4)" do
      # Arrange
      record = build(:about_page_content)
      record.slideshow_image_2.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.svg")),
        filename: "gallery_photo.svg",
        content_type: "image/svg+xml"
      )

      # Act
      record.valid?

      # Assert
      expect(record.errors[:slideshow_image_2]).to include(I18n.t("activerecord.errors.messages.invalid_content_type"))
    end

    it "rejects a file exceeding 30 MB on slideshow_image_3 (AT7, R2, E5)" do
      # Arrange
      record = build(:about_page_content)
      record.slideshow_image_3.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.jpg")),
        filename: "gallery_photo.jpg",
        content_type: "image/jpeg"
      )
      allow(record.slideshow_image_3.blob).to receive(:byte_size).and_return(31.megabytes)

      # Act
      record.valid?

      # Assert
      expect(record.errors[:slideshow_image_3]).to include(I18n.t("activerecord.errors.messages.file_too_large"))
    end

    it "accepts a slideshow file between the old 15 MB cap and the current one (AT14, AC-15, SPEC-013 R8)" do
      # Arrange
      record = build(:about_page_content)
      record.slideshow_image_3.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.jpg")),
        filename: "gallery_photo.jpg",
        content_type: "image/jpeg"
      )
      allow(record.slideshow_image_3.blob).to receive(:byte_size).and_return(20.megabytes)

      # Act
      result = record.valid?

      # Assert
      expect(result).to be true
      expect(record.errors[:slideshow_image_3]).to be_empty
    end

    it "leaves the other 2 slots' validity unaffected when one slot is invalid" do
      # Arrange
      record = build(:about_page_content)
      record.slideshow_image_2.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.svg")),
        filename: "gallery_photo.svg",
        content_type: "image/svg+xml"
      )

      # Act
      record.valid?

      # Assert
      expect(record.errors[:slideshow_image_1]).to be_empty
      expect(record.errors[:slideshow_image_3]).to be_empty
    end
  end

  describe "#slideshow_display_variant (R3)" do
    it "processes slot 1 without raising a missing-processor error" do
      # Arrange
      record = create(:about_page_content, :with_slideshow_image_1)

      # Act & Assert
      expect { record.slideshow_display_variant(1).processed }.not_to raise_error
    end

    it "drops camera metadata but keeps the ICC colour profile, matching SPEC-008's saver options" do
      # Arrange
      record = create(:about_page_content, :with_camera_metadata_slideshow_image_1)

      # Act
      variant = record.slideshow_display_variant(1)
      fields = Vips::Image.new_from_buffer(variant.processed.image.download, "").get_fields

      # Assert
      expect(fields).to include("icc-profile-data")
      expect(fields.grep(/\A(exif-|xmp-|iptc-)/)).to be_empty
    end
  end

  describe "published default" do
    it "defaults published to false for a new record" do
      # Arrange / Act
      record = AboutPageContent.new

      # Assert
      expect(record.published?).to be false
    end
  end

  describe "singleton pattern (R8)" do
    it "first_or_initialize returns the existing record when one exists" do
      # Arrange
      existing = create(:about_page_content)

      # Act
      result = AboutPageContent.first_or_initialize

      # Assert
      expect(result).to eq(existing)
      expect(result.new_record?).to be false
    end

    it "first_or_initialize returns a new unsaved record when none exists" do
      # Arrange — table is empty

      # Act
      result = AboutPageContent.first_or_initialize

      # Assert
      expect(result.new_record?).to be true
    end
  end
end
