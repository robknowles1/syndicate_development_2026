FactoryBot.define do
  factory :gallery_photo do
    sequence(:position) { |n| n }

    after(:build) do |photo|
      photo.image.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo.jpg")),
        filename: "gallery_photo.jpg",
        content_type: "image/jpeg"
      )
    end

    trait :large do
      after(:build) do |photo|
        photo.image.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/gallery_photo_large.jpg")),
          filename: "gallery_photo_large.jpg",
          content_type: "image/jpeg"
        )
      end
    end
  end
end
