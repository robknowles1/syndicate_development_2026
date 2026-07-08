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
  end
end
