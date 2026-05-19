class ServiceBullet < ApplicationRecord
  belongs_to :service_section

  validates :body, presence: true
  validates :position, presence: true
end
