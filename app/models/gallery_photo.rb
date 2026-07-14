class GalleryPhoto < ApplicationRecord
  include ImageAttachmentValidatable

  has_one_attached :image

  validate :image_must_be_attached
  validates_image_attachment :image

  def display_variant
    image.variant(resize_to_limit: [ 1200, 1200 ], saver: { quality: 80 })
  end

  private

  def image_must_be_attached
    errors.add(:image, :blank) unless image.attached?
  end
end
