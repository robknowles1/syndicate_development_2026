FactoryBot.define do
  factory :home_page_content do
    hero_tagline       { "Performance, Passion, Precision." }
    mission_heading    { "DREAM IT. BUILD IT. RIDE IT. LOVE IT." }
    mission_subheading { "SPECIALIZING IN CUSTOM PERFORMANCE MOTOCROSS AND SUPERCROSS MOTORCYCLES" }
    mission_body       { "From simple upgrades to full race ready bikes, Syndicate Development is here." }
    published          { false }

    trait :published do
      published { true }
    end

    trait :with_hero_image do
      after(:build) do |content|
        content.hero_image.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.jpg")),
          filename: "gallery_photo.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    trait :with_cta_image do
      after(:build) do |content|
        content.cta_image.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.jpg")),
          filename: "gallery_photo.jpg",
          content_type: "image/jpeg"
        )
      end
    end
  end
end
