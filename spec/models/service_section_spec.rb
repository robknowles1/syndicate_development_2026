require "rails_helper"

RSpec.describe ServiceSection, type: :model do
  subject(:section) { create(:service_section) }

  describe "validations" do
    it "is valid with a heading, icon_key, position, and at least one bullet" do
      expect(section).to be_valid
    end

    it { is_expected.to validate_presence_of(:heading) }
    it { is_expected.to validate_presence_of(:icon_key) }
    it { is_expected.to validate_presence_of(:position) }
    it "enforces slug uniqueness at the model level" do
      # The before_validation callback generates the slug, so we test uniqueness
      # by ensuring two sections with colliding headings get distinct slugs
      s1 = create(:service_section, heading: "UNIQUE NAME")
      s2 = ServiceSection.new(heading: "UNIQUE NAME", icon_key: "wrench", position: 99)
      s2.service_bullets.build(body: "bullet", position: 0)
      s2.valid?
      expect(s2.slug).not_to eq(s1.slug)
    end

    it "validates icon_key inclusion in ICON_KEYS" do
      section.icon_key = "invalid_icon"
      expect(section).not_to be_valid
      expect(section.errors[:icon_key]).to be_present
    end

    it "is valid for every value in ICON_KEYS" do
      ServiceSection::ICON_KEYS.each do |key|
        section.icon_key = key
        expect(section).to be_valid, "expected #{key} to be valid"
      end
    end

    it "is invalid when all bullets are marked for destruction" do
      section.service_bullets.each(&:mark_for_destruction)
      expect(section).not_to be_valid
      expect(section.errors[:base]).to include(
        I18n.t("activerecord.errors.models.service_section.attributes.base.at_least_one_bullet")
      )
    end

    it "is valid when at least one bullet survives destruction marking" do
      create(:service_bullet, service_section: section, position: 1)
      section.reload
      section.service_bullets.first.mark_for_destruction
      expect(section).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:service_bullets).dependent(:destroy) }
  end

  describe "slug auto-generation" do
    it "generates slug from heading on create" do
      s = create(:service_section, heading: "PRECISION ENGINES")
      expect(s.slug).to eq("precision_engines")
    end

    it "regenerates slug when heading changes" do
      s = create(:service_section, heading: "OLD NAME")
      s.update!(heading: "NEW NAME")
      expect(s.slug).to eq("new_name")
    end

    it "does not regenerate slug when an unrelated attribute changes" do
      s = create(:service_section, heading: "PRECISION ENGINES")
      original_slug = s.slug
      s.update_column(:position, 99)
      s.reload
      expect(s.slug).to eq(original_slug)
    end

    it "appends a numeric suffix when slug collides with another section (AT13)" do
      create(:service_section, heading: "Engines")
      # Force slug "engines" to be taken
      existing = ServiceSection.last
      expect(existing.slug).to eq("engines")

      # Create another section that would generate the same slug
      s = ServiceSection.new(
        heading: "Engines",
        icon_key: "wrench",
        position: 99
      )
      s.service_bullets.build(body: "Some bullet", position: 0)
      s.valid?
      expect(s.slug).to match(/\Aengines_\d+\z/)
      expect(s.slug).not_to eq("engines")
    end
  end

  describe "ICON_KEYS constant" do
    it "contains exactly 12 values" do
      expect(ServiceSection::ICON_KEYS.length).to eq(12)
    end
  end
end
