module Admin
  class InviteAdminUser
    Result = Struct.new(:admin_user, :status)

    def initialize(email)
      @email = email
    end

    def call
      admin_user = build_invitee
      return Result.new(admin_user, :invalid) unless admin_user.save

      deliver_invitation(admin_user)
    end

    private

    def build_invitee
      admin_user = AdminUser.new(email: @email, invited_at: Time.current)
      # A placeholder the invitee never learns; they set a real one via the emailed link.
      # has_secure_password requires a password on create, so it cannot be left blank.
      admin_user.password = SecureRandom.base58(32)
      admin_user
    end

    def deliver_invitation(admin_user)
      AdminMailer.invitation(admin_user).deliver_now
      Result.new(admin_user, :invited)
    rescue StandardError => error
      # The saved row occupies the address, and uniqueness then refuses a second invite,
      # so an undelivered invitation would permanently block inviting that person. Undo it.
      Rails.error.report(error, handled: true)
      destroy_undelivered_invitee(admin_user)
      Result.new(admin_user, :delivery_failed)
    end

    def destroy_undelivered_invitee(admin_user)
      admin_user.destroy
    rescue StandardError => error
      # Raising here would 500 the invite form and leave the row behind anyway, which is
      # the outcome this rescue exists to avoid reporting as a success.
      Rails.error.report(error, handled: true)
    end
  end
end
