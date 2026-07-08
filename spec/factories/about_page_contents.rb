FactoryBot.define do
  factory :about_page_content do
    shop_heading       { "SYNDICATE DEVELOPMENT" }
    shop_phone_label   { "Shop Phone:" }
    shop_phone_number  { "208-251-9536" }
    shop_address_label { "Shop Address:" }
    shop_address       { "1801 N. Arthur Ave., Pocatello, ID, 83204" }
    bio_heading        { "About Doug Haskett" }
    bio_body           { "Doug Haskett has been involved with motorcycles and racing for most of his life." }
    slideshow_alt_1    { "Syndicate Development motorcycle 1" }
    slideshow_alt_2    { "Syndicate Development motorcycle 2" }
    slideshow_alt_3    { "Syndicate Development motorcycle 3" }
    published          { false }

    trait :published do
      published { true }
    end
  end
end
