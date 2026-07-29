class AdminMailer < ApplicationMailer
  def invitation(admin_user)
    @admin_user = admin_user
    @url = admin_claim_invitation_url(token: admin_user.generate_token_for(:invitation))

    mail(to: admin_user.email, subject: I18n.t("admin_mailer.invitation.subject"))
  end

  def password_reset(admin_user)
    @admin_user = admin_user
    @url = admin_claim_password_reset_url(token: admin_user.generate_token_for(:password_reset))

    mail(to: admin_user.email, subject: I18n.t("admin_mailer.password_reset.subject"))
  end
end
