class AboutPageContent < ApplicationRecord
  PHONE_NUMBER_FORMAT = /\A(?=.*\d)[0-9\s\-\+\.\(\)]+\z/

  validates :shop_heading, :shop_phone_label, :shop_phone_number, :shop_address_label,
            :shop_address, :bio_heading, :bio_body,
            :slideshow_alt_1, :slideshow_alt_2, :slideshow_alt_3, presence: true
  validates :shop_phone_number, format: { with: PHONE_NUMBER_FORMAT }
end
