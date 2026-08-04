class GalleryPhoto < ApplicationRecord
  include ImageAttachmentValidatable

  has_one_attached :image

  validate :image_must_be_attached
  validates_image_attachment :image

  def display_variant
    image.variant(resize_to_limit: [ 1200, 1200 ], saver: { quality: 80, keep: :icc })
  end

  # resize_to_fill, not resize_to_limit: grid tiles are aspect-square/object-cover,
  # so a limit-fitted variant is upscaled and re-cropped by the browser (R10).
  def thumbnail_variant
    image.variant(resize_to_fill: [ 600, 600 ], saver: { quality: 80, keep: :icc })
  end

  private

  def image_must_be_attached
    errors.add(:image, :blank) unless image.attached?
  end
end
