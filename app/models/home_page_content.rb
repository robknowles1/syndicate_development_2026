class HomePageContent < ApplicationRecord
  include ImageAttachmentValidatable

  attr_accessor :remove_hero_image, :remove_cta_image

  has_one_attached :hero_image
  has_one_attached :cta_image

  validates :hero_tagline,       presence: true, length: { maximum: 50 }
  validates :mission_heading,    presence: true
  validates :mission_subheading, presence: true
  validates :mission_body,       presence: true
  validates_image_attachment :hero_image, :cta_image

  def hero_display_variant
    hero_image.variant(resize_to_limit: [ 1200, 1200 ], saver: { quality: 80, keep: :icc })
  end

  def cta_display_variant
    cta_image.variant(resize_to_limit: [ 1200, 1200 ], saver: { quality: 80, keep: :icc })
  end

  # resize_to_fill, not resize_to_limit: social scrapers crop a non-1.91:1 image
  # unpredictably rather than letterboxing it, so the crop is made here (R4).
  def social_share_variant
    hero_image.variant(resize_to_fill: [ 1200, 630 ], saver: { quality: 80, keep: :icc })
  end
end
