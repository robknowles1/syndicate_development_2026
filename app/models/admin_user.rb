class AdminUser < ApplicationRecord
  MINIMUM_PASSWORD_LENGTH = 12

  has_secure_password

  # Not persisted. Backs the "confirm your current password" field on the account form
  # so it can use the form builder and carry validation errors like any other field.
  attr_accessor :current_password

  # Applies to finder values as well as writes, so find_by(email: "Doug@…") matches a
  # row stored as "doug@…". Without it the case-insensitive uniqueness validation and
  # the case-sensitive lookup disagree, and an admin can be locked out of their account.
  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email address" }

  # allow_nil so updates that do not touch the password are not rejected.
  # has_secure_password still requires one on create and caps length at 72 bytes.
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true

  # Both tokens derive from the password salt, so setting a password invalidates any
  # outstanding link for this account. That makes each link single-use in practice, and
  # means a leaked invitation cannot be replayed after it has been accepted.
  generates_token_for :invitation, expires_in: 7.days do
    password_salt&.last(10)
  end

  generates_token_for :password_reset, expires_in: 2.hours do
    password_salt&.last(10)
  end

  scope :pending_invitation, -> { where(invitation_accepted_at: nil).where.not(invited_at: nil) }

  def invitation_pending?
    invited_at.present? && invitation_accepted_at.nil?
  end

  # Whether this account may sign in. An invited admin who has not yet set a password
  # holds only the random placeholder assigned at invite time.
  def active?
    !invitation_pending?
  end

  def accept_invitation(password:, password_confirmation:)
    update(
      password: password,
      password_confirmation: password_confirmation,
      invitation_accepted_at: Time.current
    )
  end
end
