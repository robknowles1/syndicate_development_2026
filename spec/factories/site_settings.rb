FactoryBot.define do
  factory :site_setting do
    sequence(:key) { |n| "setting_key_#{n}" }
    value { "false" }
  end
end
