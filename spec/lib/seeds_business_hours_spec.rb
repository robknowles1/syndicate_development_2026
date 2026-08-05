require "rails_helper"

RSpec.describe "db/seeds.rb business hours seeding" do
  def seed
    original = ENV["ADMIN_SEED_PASSWORD"]
    ENV["ADMIN_SEED_PASSWORD"] = "seed-password-1234"
    Rails.application.load_seed
  ensure
    original.nil? ? ENV.delete("ADMIN_SEED_PASSWORD") : ENV["ADMIN_SEED_PASSWORD"] = original
  end

  context "with a clean database" do
    it "persists exactly one row with every day left blank (AT17, AC-19)" do
      # Act
      seed

      # Assert
      expect(BusinessHours.count).to eq(1)
      expect(BusinessHours.sole.attributes.values_at(
        *BusinessHours::DAYS.flat_map { |day| [ "#{day}_opens_at", "#{day}_closes_at" ] }
      )).to all(be_nil)
    end
  end

  context "when seeding runs twice" do
    it "neither raises nor creates a second row (AT17, AC-19)" do
      # Arrange
      seed

      # Act
      seed

      # Assert
      expect(BusinessHours.count).to eq(1)
    end
  end

  context "when an admin has already entered hours" do
    it "leaves them untouched on a reseed (R15)" do
      # Arrange
      seed
      BusinessHours.sole.update!(friday_opens_at: "09:00", friday_closes_at: "17:00")

      # Act
      seed

      # Assert
      expect(BusinessHours.sole.friday_opens_at.strftime("%H:%M")).to eq("09:00")
      expect(BusinessHours.count).to eq(1)
    end
  end
end
