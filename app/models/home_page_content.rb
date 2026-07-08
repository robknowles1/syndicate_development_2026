class HomePageContent < ApplicationRecord
  validates :hero_tagline,       presence: true, length: { maximum: 50 }
  validates :mission_heading,    presence: true
  validates :mission_subheading, presence: true
  validates :mission_body,       presence: true
end
