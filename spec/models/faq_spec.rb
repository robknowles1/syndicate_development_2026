require "rails_helper"

RSpec.describe Faq, type: :model do
  subject { build(:faq) }

  describe "the faqs table" do
    it "carries exactly question, answer, position and timestamps (AT1, AC-1)" do
      expect(described_class.column_names).to contain_exactly(
        "id", "question", "answer", "position", "created_at", "updated_at"
      )
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:question) }
    it { is_expected.to validate_presence_of(:answer) }

    it "is invalid with a blank answer (AT2, AC-2, E2)" do
      # Arrange
      faq = build(:faq, answer: "")

      # Act
      valid = faq.valid?

      # Assert
      expect(valid).to be(false)
      expect(faq.errors[:answer]).to be_present
    end

    it "is valid with a question and an answer" do
      expect(build(:faq)).to be_valid
    end
  end
end
