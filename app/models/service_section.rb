class ServiceSection < ApplicationRecord
  ICON_KEYS = %w[
    wrench wrench-screwdriver bolt fire beaker
    adjustments-horizontal adjustments-vertical cpu-chip chart-bar
    cog-6-tooth cog-8-tooth cube sparkles trophy
  ].freeze

  has_many :service_bullets, -> { order(:position) }, dependent: :destroy
  accepts_nested_attributes_for :service_bullets, allow_destroy: true, reject_if: :all_blank

  validates :slug, presence: true, uniqueness: true
  validates :heading, presence: true
  validates :icon_key, presence: true, inclusion: { in: ICON_KEYS }
  validates :position, presence: true, numericality: { only_integer: true }

  validate :at_least_one_bullet

  before_validation :generate_slug_from_heading

  private

  def generate_slug_from_heading
    return unless will_save_change_to_heading? || slug.blank?
    return if heading.blank?

    base = heading.parameterize(separator: "_")
    candidate = base
    counter = 2
    loop do
      existing = ServiceSection.where(slug: candidate).where.not(id: id)
      break unless existing.exists?

      candidate = "#{base}_#{counter}"
      counter += 1
    end
    self.slug = candidate
  end

  # NOTE: relies on service_bullets being preloaded. Callers that query ServiceSection
  # for validation purposes must use `.includes(:service_bullets)` to avoid N+1 and
  # to ensure `reject(&:marked_for_destruction?)` operates on the full in-memory collection.
  def at_least_one_bullet
    surviving = service_bullets.reject(&:marked_for_destruction?)
    errors.add(:base, :at_least_one_bullet) if surviving.empty?
  end
end
