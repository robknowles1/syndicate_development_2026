require "rails_helper"

RSpec.describe ServiceBullet, type: :model do
  describe "validations" do
    subject(:bullet) { build(:service_bullet) }

    it "is valid with a body and position" do
      expect(bullet).to be_valid
    end

    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:position) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:service_section) }
  end
end
