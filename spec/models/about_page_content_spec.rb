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
