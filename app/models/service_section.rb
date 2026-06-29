class ServiceSection < ApplicationRecord
  has_many :service_bullets, -> { order(:position) }, dependent: :destroy
  accepts_nested_attributes_for :service_bullets, allow_destroy: true, reject_if: :all_blank

  validates :slug, presence: true, uniqueness: true
  validates :heading, presence: true

  validate :at_least_one_bullet

  private

  def at_least_one_bullet
    if service_bullets.loaded?
      surviving = service_bullets.reject(&:marked_for_destruction?)
      errors.add(:base, :at_least_one_bullet) if surviving.empty?
    elsif persisted?
      errors.add(:base, :at_least_one_bullet) if service_bullets.count < 1
    end
  end
end
