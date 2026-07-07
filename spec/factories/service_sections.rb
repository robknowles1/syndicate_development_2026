FactoryBot.define do
  # Base factory without any bullets — used as association target in the service_bullet factory
  # to avoid circular dependency. Skips bullet-count validation since bullets are created
  # separately after the section is persisted.
  factory :service_section_without_bullet, class: "ServiceSection" do
    sequence(:heading) { |n| "Test Section Heading #{n}" }
    sequence(:slug)    { |n| "test_section_heading_#{n}" }
    icon_key  { "tool" }
    sequence(:position) { |n| n }
    to_create { |instance| instance.save!(validate: false) }
  end

  # Default factory: builds one bullet inline so at_least_one_bullet validation passes on create.
  factory :service_section do
    sequence(:heading) { |n| "Test Section Heading #{n}" }
    icon_key { "tool" }
    sequence(:position) { |n| n }

    after(:build) do |section|
      section.service_bullets.build(body: "Default bullet item", position: 0)
    end
  end
end
