class ContactMailer < ApplicationMailer
  def contact_email(name:, email:, subject:, message:)
    @name = name
    @email = email
    @subject = subject
    @message = message

    mail(
      to: "robknowles105@gmail.com",
      reply_to: email,
      subject: "#{I18n.t('mailer.contact_email.subject_prefix')} #{subject}"
    )
  end
end
