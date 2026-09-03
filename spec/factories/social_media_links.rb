FactoryBot.define do
  factory :social_media_link do
    platform { SocialMediaLink::PLATFORMS.first }
    url { "https://instagram.com/syndicate" }
    sequence(:position) { |n| n - 1 }
    active { true }
  end
end
