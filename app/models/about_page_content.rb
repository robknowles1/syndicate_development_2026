class AboutPageContent < ApplicationRecord
  include ImageAttachmentValidatable

  PHONE_NUMBER_FORMAT = /\A(?=.*\d)[0-9\s\-\+\.\(\)]+\z/

  has_one_attached :slideshow_image_1
  has_one_attached :slideshow_image_2
  has_one_attached :slideshow_image_3

  validates :shop_heading, :shop_phone_label, :shop_phone_number, :shop_address_label,
            :shop_address, :bio_heading, :bio_body,
            :slideshow_alt_1, :slideshow_alt_2, :slideshow_alt_3, presence: true
  validates :shop_phone_number, format: { with: PHONE_NUMBER_FORMAT }
  validates_image_attachment :slideshow_image_1, :slideshow_image_2, :slideshow_image_3

  def slideshow_display_variant(slot_number)
    public_send("slideshow_image_#{slot_number}").variant(resize_to_limit: [ 1200, 1200 ], saver: { quality: 80, keep: :icc })
  end
end
