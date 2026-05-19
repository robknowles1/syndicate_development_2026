class AdminUser < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email address" }
end
