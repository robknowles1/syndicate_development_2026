class SocialMediaLink < ApplicationRecord
  PLATFORMS = %w[instagram facebook youtube tiktok x threads linkedin].freeze

  # Anchored deliberately: an unanchored regexp matches anywhere in the string, so
  # `javascript:alert("https://x")` would pass and become an href on every public page.
  HTTP_URL_FORMAT = /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/

  scope :active, -> { where(active: true) }

  validates :platform, presence: true, inclusion: { in: PLATFORMS }, uniqueness: true
  validates :url, presence: true, format: { with: HTTP_URL_FORMAT, allow_blank: true }
  validates :position, presence: true, numericality: { only_integer: true }

  def icon_key
    "brand-#{platform}"
  end

  def platform_label
    I18n.t("social_media.platforms.#{platform}")
  end
end
