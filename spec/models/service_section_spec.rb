require "rails_helper"

RSpec.describe ServiceSection, type: :model do
  subject(:section) { create(:service_section) }

  describe "validations" do
    it "is valid with a slug, heading, and at least one bullet" do
      expect(section).to be_valid
    end

    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:heading) }
    it { is_expected.to validate_uniqueness_of(:slug) }

    it "is invalid when all bullets are marked for destruction" do
      # Load association and mark all bullets for destruction
      section.service_bullets.each(&:mark_for_destruction)
      expect(section).not_to be_valid
      expect(section.errors[:base]).to include(I18n.t("activerecord.errors.models.service_section.attributes.base.at_least_one_bullet"))
    end

    it "is valid when at least one bullet survives destruction marking" do
      create(:service_bullet, service_section: section, position: 1)
      section.reload
      # Mark the first bullet for destruction, keep the second
      section.service_bullets.first.mark_for_destruction
      expect(section).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:service_bullets).dependent(:destroy) }
  end
end
