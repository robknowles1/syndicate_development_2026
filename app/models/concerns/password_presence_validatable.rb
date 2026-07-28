module PasswordPresenceValidatable
  extend ActiveSupport::Concern

  included do
    validate :password_assignment_must_not_be_blank
  end

  # has_secure_password treats `password = ""` as "no change", leaving the previous digest
  # intact. The length validation is then skipped too, because `password` reads back nil on
  # a freshly loaded record. Both together let a blank submission report success while the
  # old password still works, so record the attempt and reject it.
  def password=(unencrypted_password)
    @password_assigned_blank = unencrypted_password.is_a?(String) && unencrypted_password.empty?
    @password_assigned = true
    super
  end

  # The entry point for every flow whose purpose is to set a password. Permitted params drop
  # keys the form did not send, and an absent :password key never reaches `password=` at all,
  # so there is no blank assignment to record and a plain `update` reports success against
  # whatever digest was already there — including the placeholder an invitee was never told.
  def update_password(attributes)
    @password_assignment_required = true
    @password_assigned = false
    @password_assigned_blank = false
    update(attributes)
  ensure
    @password_assignment_required = false
  end

  private

  # Deliberately reads the assignment flags rather than the `password` attribute: on an
  # instance that was handed a password earlier in its life, the reader still returns that
  # earlier value even though `password = ""` changed nothing.
  def password_assignment_must_not_be_blank
    return unless @password_assigned_blank || (@password_assignment_required && !@password_assigned)

    # has_secure_password reports a missing digest on this same attribute, and the admin
    # should not be told twice.
    errors.add(:password, :blank) unless errors.added?(:password, :blank)
  end
end
