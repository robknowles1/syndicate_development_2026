FactoryBot.define do
  # Base factory without any bullets — used internally to avoid circular dependency
  factory :service_section_without_bullet, class: "ServiceSection" do
    sequence(:slug) { |n| "section_slug_#{n}" }
    heading { "Test Section Heading" }
  end

  # Default factory: creates a section with one bullet so validations pass
  factory :service_section do
    sequence(:slug) { |n| "section_slug_#{n}" }
    heading { "Test Section Heading" }

    after(:create) do |section|
      create(:service_bullet, service_section: section, position: 0)
    end
  end
end
