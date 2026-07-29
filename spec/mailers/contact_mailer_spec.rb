require "rails_helper"

RSpec.describe ContactMailer, type: :mailer do
  def enquiry_email
    described_class.contact_email(
      name: "Jane Rider",
      email: "jane@example.com",
      subject: "Engine build question",
      message: "I would like to enquire about a full engine build."
    )
  end

  describe "#contact_email" do
    it "uses the locale key value for the subject prefix" do
      expect(enquiry_email.subject).to start_with(I18n.t("mailer.contact_email.subject_prefix"))
    end

    it "includes the caller-supplied subject after the prefix" do
      expect(enquiry_email.subject).to include("Engine build question")
    end

    it "addresses the developer, never the shop, outside production" do
      expect(enquiry_email.to).to eq([ "robknowles105@gmail.com" ])
    end

    it "sends from the verified no-reply address, not the Rails placeholder" do
      expect(enquiry_email.from).to eq([ "noreply@mail.syndicate-development.com" ])
    end

    it "sets reply-to to the sender's email" do
      expect(enquiry_email.reply_to).to eq([ "jane@example.com" ])
    end
  end

  describe "#contact_email with the optional phone field" do
    it "includes the phone number in both parts when supplied" do
      # Arrange / Act
      mail = ContactMailer.contact_email(
        name: "Jane Rider", email: "jane@example.com", phone: "208-555-0123",
        subject: "Suspension", message: "Question about forks."
      )

      # Assert
      expect(mail.html_part.body.to_s).to include("208-555-0123")
      expect(mail.text_part.body.to_s).to include("208-555-0123")
    end

    it "omits the phone label entirely when blank" do
      # Arrange / Act
      mail = ContactMailer.contact_email(
        name: "Jane Rider", email: "jane@example.com", phone: "",
        subject: "Suspension", message: "Question about forks."
      )

      # Assert
      expect(mail.html_part.body.to_s).not_to include(I18n.t("mailer.contact_email.phone_label"))
      expect(mail.text_part.body.to_s).not_to include(I18n.t("mailer.contact_email.phone_label"))
    end

    it "remains callable without the phone argument" do
      # Arrange / Act — the field is new; existing callers must not break
      mail = ContactMailer.contact_email(
        name: "Jane Rider", email: "jane@example.com",
        subject: "Suspension", message: "Question about forks."
      )

      # Assert
      expect(mail.html_part.body.to_s).not_to include(I18n.t("mailer.contact_email.phone_label"))
    end
  end
end
