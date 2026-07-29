class AdminUser < ApplicationRecord
  MINIMUM_PASSWORD_LENGTH = 12

  has_secure_password

  # Must come after has_secure_password so its password= override sits ahead of the
  # generated one in the ancestor chain.
  include PasswordPresenceValidatable

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

  # Looks the account up and always performs one bcrypt comparison, including when no
  # account matches. Returning early on an unknown address would make the response
  # measurably faster for addresses that have no admin account, which is enough to
  # enumerate them.
  def self.authenticate_by_email(email, password)
    admin_user = find_by(email: email)

    if admin_user.nil?
      # Spend the same bcrypt work on an address with no account as on a wrong password.
      # Returning straight away here is what made a registered address measurable — 304ms
      # against ~2ms at production cost, a reliable enumeration oracle.
      BCrypt::Password.new(unmatchable_password_digest).is_password?(password.to_s)
      return nil
    end

    admin_user.authenticate(password) || nil
  end

  # Cost must track has_secure_password's, or the dummy comparison takes a different
  # amount of time than a real one and reintroduces the very difference it hides.
  def self.unmatchable_password_digest
    @unmatchable_password_digest ||= BCrypt::Password.create(
      SecureRandom.base58(32),
      cost: ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
    )
  end

  def invitation_pending?
    invited_at.present? && invitation_accepted_at.nil?
  end

  # Whether this account may sign in. An invited admin who has not yet set a password
  # holds only the random placeholder assigned at invite time.
  def active?
    !invitation_pending?
  end

  # Takes a hash rather than keywords: permitted params omit keys the form did not send,
  # and splatting those into required keywords raises rather than validating.
  def accept_invitation(password_attributes)
    update_password(
      password_attributes.to_h.symbolize_keys.merge(invitation_accepted_at: Time.current)
    )
  end

  # Setting a password through a reset link proves control of the mailbox, which is the
  # same thing an invitation asks for, so it settles a still-pending invitation too.
  # Without this the account would be signed in while active? still reads false.
  def reset_password(password_attributes)
    update_password(
      password_attributes.to_h.symbolize_keys.merge(
        invitation_accepted_at: invitation_accepted_at || Time.current
      )
    )
  end

  def change_password(password_attributes)
    update_password(password_attributes.to_h.symbolize_keys)
  end

  # Rotated at every sign-in and cleared at logout. The cookie store keeps nothing
  # server-side, so without a value on the row there is nothing a logout could revoke and a
  # captured cookie would stay usable until the password changed.
  def rotate_session_token!
    generated = SecureRandom.hex(32)
    update_column(:session_token, generated)
    generated
  end

  def clear_session_token!
    update_column(:session_token, nil)
  end
end
