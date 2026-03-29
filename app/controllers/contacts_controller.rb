class ContactsController < ApplicationController
  def create
    name = params[:name].to_s.strip
    email = params[:email].to_s.strip
    subject = params[:subject].to_s.strip
    message = params[:message].to_s.strip

    if name.blank? || email.blank? || message.blank?
      redirect_to about_path, alert: "Please fill in all required fields (name, email, and message)."
    else
      ContactMailer.contact_email(
        name: name,
        email: email,
        subject: subject.presence || "(No subject)",
        message: message
      ).deliver_now
      redirect_to about_path, notice: "Message sent! We'll be in touch soon."
    end
  end
end
