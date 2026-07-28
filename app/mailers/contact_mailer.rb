class ContactMailer < ApplicationMailer
  # phone is optional on the contact form, so it defaults to blank for any caller that
  # predates the field.
  def contact_email(name:, email:, subject:, message:, phone: nil)
    @name = name
    @email = email
    @phone = phone.presence
    @subject = subject
    @message = message

    mail(
      to: "robknowles105@gmail.com",
      reply_to: email,
      subject: "#{I18n.t('mailer.contact_email.subject_prefix')} #{subject}"
    )
  end
end
