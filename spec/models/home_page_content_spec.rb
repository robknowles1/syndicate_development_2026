require "rails_helper"

RSpec.describe HomePageContent, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:hero_tagline) }
    it { is_expected.to validate_presence_of(:mission_heading) }
    it { is_expected.to validate_presence_of(:mission_subheading) }
    it { is_expected.to validate_presence_of(:mission_body) }

    it "is valid with all required fields" do
      # Arrange / Act
      record = build(:home_page_content)

      # Assert
      expect(record).to be_valid
    end

    describe "hero_tagline length (R6)" do
      it "is valid with exactly 50 characters (E3)" do
        # Arrange
        record = build(:home_page_content, hero_tagline: "A" * 50)

        # Act / Assert
        expect(record).to be_valid
      end

      it "is invalid with 51 characters (E4)" do
        # Arrange
        record = build(:home_page_content, hero_tagline: "A" * 51)

        # Act
        record.valid?

        # Assert
        expect(record.errors[:hero_tagline]).to be_present
      end

      it "is valid at the 50-character Unicode boundary" do
        # Arrange — 50 Unicode characters (multi-byte chars still count as 1)
        record = build(:home_page_content, hero_tagline: "é" * 50)

        # Act / Assert
        expect(record).to be_valid
      end
    end

    it "rejects hero_tagline with all-whitespace (blank?)" do
      # Arrange
      record = build(:home_page_content, hero_tagline: "   ")

      # Act
      record.valid?

      # Assert
      expect(record.errors[:hero_tagline]).to be_present
    end

    it "rejects mission_body with all-whitespace (E7)" do
      # Arrange
      record = build(:home_page_content, mission_body: "   ")

      # Act
      record.valid?

      # Assert
      expect(record.errors[:mission_body]).to be_present
    end
  end

  describe "hero_image and cta_image attachments (SPEC-013 R1, R2)" do
    it "is valid with neither slot attached — presence is not required (AT1, R2)" do
      # Arrange
      record = build(:home_page_content)

      # Act
      result = record.valid?

      # Assert
      expect(result).to be true
      expect(record.errors[:hero_image]).to be_empty
      expect(record.errors[:cta_image]).to be_empty
    end

    it "is valid with a JPEG attached to each slot (AT2, AT3, R1)" do
      # Arrange
      record = build(:home_page_content, :with_hero_image, :with_cta_image)

      # Act
      result = record.valid?

      # Assert
      expect(result).to be true
      expect(record.hero_image).to be_attached
      expect(record.cta_image).to be_attached
    end

    it "rejects an image/svg+xml content type on cta_image (AT11, R2, E5)" do
      # Arrange
      record = build(:home_page_content)
      record.cta_image.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.svg")),
        filename: "gallery_photo.svg",
        content_type: "image/svg+xml"
      )

      # Act
      record.valid?

      # Assert
      expect(record.errors[:cta_image]).to include(I18n.t("activerecord.errors.messages.invalid_content_type"))
    end

    it "rejects a hero_image exceeding 30 MB (AT12, R8, E6)" do
      # Arrange
      record = build(:home_page_content, :with_hero_image)
      allow(record.hero_image.blob).to receive(:byte_size).and_return(31.megabytes)

      # Act
      record.valid?

      # Assert
      expect(record.errors[:hero_image]).to include(I18n.t("activerecord.errors.messages.file_too_large"))
    end

    it "accepts a hero_image at exactly 30 MB (AT13, R8)" do
      # Arrange
      record = build(:home_page_content, :with_hero_image)
      allow(record.hero_image.blob).to receive(:byte_size).and_return(30.megabytes)

      # Act
      result = record.valid?

      # Assert
      expect(result).to be true
      expect(record.errors[:hero_image]).to be_empty
    end

    it "leaves the other slot's validity unaffected when one slot is invalid (R6)" do
      # Arrange
      record = build(:home_page_content, :with_hero_image)
      record.cta_image.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.svg")),
        filename: "gallery_photo.svg",
        content_type: "image/svg+xml"
      )

      # Act
      record.valid?

      # Assert
      expect(record.errors[:hero_image]).to be_empty
      expect(record.errors[:cta_image]).to be_present
    end
  end

  describe "image variants (SPEC-013 R3, R4)" do
    it "fits hero_display_variant inside 1200x1200 without cropping (R3)" do
      # Arrange
      record = build(:home_page_content, :with_hero_image)

      # Act
      transformations = record.hero_display_variant.variation.transformations

      # Assert
      expect(transformations).to include(resize_to_limit: [ 1200, 1200 ], saver: { quality: 80, keep: :icc })
      expect(transformations).not_to have_key(:resize_to_fill)
    end

    it "fits cta_display_variant inside 1200x1200 without cropping (R3)" do
      # Arrange
      record = build(:home_page_content, :with_cta_image)

      # Act
      transformations = record.cta_display_variant.variation.transformations

      # Assert
      expect(transformations).to include(resize_to_limit: [ 1200, 1200 ], saver: { quality: 80, keep: :icc })
      expect(transformations).not_to have_key(:resize_to_fill)
    end

    it "crops social_share_variant to the 1200x630 social aspect ratio from the hero slot (R4)" do
      # Arrange
      record = build(:home_page_content, :with_hero_image)

      # Act
      transformations = record.social_share_variant.variation.transformations

      # Assert
      expect(transformations).to include(resize_to_fill: [ 1200, 630 ], saver: { quality: 80, keep: :icc })
      expect(transformations).not_to have_key(:resize_to_limit)
    end
  end

  describe "alt text is deliberately absent (SPEC-013 R11, AC-24)" do
    it "exposes no alt-text attribute for either background slot" do
      # Arrange / Act
      attribute_names = described_class.column_names + described_class.new.attributes.keys

      # Assert
      expect(attribute_names.grep(/alt/i)).to be_empty
    end
  end

  describe "published default (R10)" do
    it "defaults published to false for a new record" do
      # Arrange / Act
      record = HomePageContent.new

      # Assert
      expect(record.published?).to be false
    end
  end

  describe "singleton pattern (R10, R11)" do
    it "first_or_initialize returns the existing record when one exists" do
      # Arrange
      existing = create(:home_page_content)

      # Act
      result = HomePageContent.first_or_initialize

      # Assert
      expect(result).to eq(existing)
      expect(result.new_record?).to be false
    end

    it "first_or_initialize returns a new unsaved record when none exists" do
      # Arrange — table is empty

      # Act
      result = HomePageContent.first_or_initialize

      # Assert
      expect(result.new_record?).to be true
    end
  end
end
