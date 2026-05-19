class ContactsController < ApplicationController
  def create
    name = params[:name].to_s.strip
    email = params[:email].to_s.strip
    subject = params[:subject].to_s.strip
    message = params[:message].to_s.strip

    if name.blank? || email.blank? || message.blank?
      redirect_to about_path, alert: I18n.t("contact.errors.missing_required_fields")
    else
      ContactMailer.contact_email(
        name: name,
        email: email,
        subject: subject.presence || I18n.t("contact.form.no_subject"),
        message: message
      ).deliver_now
      redirect_to about_path, notice: I18n.t("contact.notices.message_sent")
    end
  end
end
