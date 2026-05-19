FactoryBot.define do
  factory :service_bullet do
    body { "Example bullet item" }
    position { 0 }
    association :service_section, factory: :service_section_without_bullet
  end
end
