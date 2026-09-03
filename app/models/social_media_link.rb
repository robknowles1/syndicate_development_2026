class SocialMediaLink < ApplicationRecord
  PLATFORMS = %w[instagram facebook youtube tiktok x threads linkedin].freeze

  # Anchored deliberately: an unanchored regexp matches anywhere in the string, so
  # `javascript:alert("https://x")` would pass and become an href on every public page.
  HTTP_URL_FORMAT = /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/

  scope :active, -> { where(active: true) }

  validates :platform, presence: true, inclusion: { in: PLATFORMS }, uniqueness: true
  validates :url, presence: true, format: { with: HTTP_URL_FORMAT, allow_blank: true }
  # Must stay declared after the format validation above: it reads errors[:url] to stay
  # silent when the format check already rejected the value, and validations run in
  # declaration order. Hoisting it up to group the `validates` calls together yields two
  # "Url is invalid" messages on the same field.
  validate :url_must_have_a_host
  validates :position, presence: true, numericality: { only_integer: true }

  def icon_key
    "brand-#{platform}"
  end

  def platform_label
    I18n.t("social_media.platforms.#{platform}")
  end

  private

  def url_must_have_a_host
    return if url.blank? || errors[:url].any?

    errors.add(:url, :invalid) if URI::DEFAULT_PARSER.parse(url).host.blank?
  rescue URI::InvalidURIError
    errors.add(:url, :invalid)
  end
end
