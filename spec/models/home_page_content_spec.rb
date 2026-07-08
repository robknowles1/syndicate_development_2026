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
