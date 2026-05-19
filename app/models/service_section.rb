class ServiceSection < ApplicationRecord
  has_many :service_bullets, -> { order(:position) }, dependent: :destroy
  accepts_nested_attributes_for :service_bullets, allow_destroy: true, reject_if: :all_blank

  validates :slug, presence: true, uniqueness: true
  validates :heading, presence: true

  validate :at_least_one_bullet

  private

  def at_least_one_bullet
    # Only enforce minimum-bullet constraint when the association has been loaded
    # (i.e., nested attributes were submitted). Skips validation during initial seed creation.
    return unless service_bullets.loaded?

    surviving_bullets = service_bullets.reject { |b| b.marked_for_destruction? }
    if surviving_bullets.empty?
      errors.add(:base, I18n.t("admin.services_page.validation_error"))
    end
  end
end
