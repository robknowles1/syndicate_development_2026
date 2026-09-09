FactoryBot.define do
  factory :gallery_photo do
    sequence(:position) { |n| n }

    after(:build) do |photo|
      photo.image.attach(
        io: ImageFixtureUploads.image_fixture_io("gallery_photo.jpg"),
        filename: "gallery_photo.jpg",
        content_type: "image/jpeg"
      )
    end

    trait :large do
      after(:build) do |photo|
        photo.image.attach(
          io: ImageFixtureUploads.image_fixture_io("gallery_photo_large.jpg"),
          filename: "gallery_photo_large.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    trait :with_camera_metadata do
      after(:build) do |photo|
        photo.image.attach(
          io: ImageFixtureUploads.image_fixture_io("gallery_photo_with_metadata.jpg"),
          filename: "gallery_photo_with_metadata.jpg",
          content_type: "image/jpeg"
        )
      end
    end
  end
end
